# Copyright (C) 2021 saytamkenorh
#
# This file is part of Turtlico.
#
# Turtlico is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Turtlico is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Turtlico.  If not, see <http://www.gnu.org/licenses/>.

import os
import sys
import tempfile
import subprocess
import threading
import signal
from typing import Union, Tuple

from gi.repository import GObject, GLib

import turtlico.compiler as compiler
import turtlico.utils as utils
from turtlico.locale import _

_launcher = """
try:
    exec(open('{0}').read(), {{'__file__':'{0}'}})
except SyntaxError as e:
    import sys
    print(f'TURTLICO_TRACE:{{e.lineno}}', file=sys.stderr)
    print('Syntax error', file=sys.stderr)
except Exception as e:
    import sys, traceback
    exception_type, exception_object, exception_traceback = sys.exc_info()
    trace = traceback.extract_tb(exception_traceback)
    line_numbers = ','.join(reversed([str(t[1]) for t in trace]))
    print(f'TURTLICO_TRACE:{{line_numbers}}', file=sys.stderr)
    message = str(e).strip()
    if message != '':
        print(message, file=sys.stderr)
"""


class DebuggingReuslt(GObject.Object):
    program_failed = GObject.Property(type=bool, default=False)
    error_message = GObject.Property(type=str)

    def __init__(self, debug_info: compiler.DebugInfo, stderr: str):
        super().__init__()
        if stderr:
            self.program_failed = True
            debug_info = dict(sorted(debug_info.items()))
            stderr_lines = stderr.splitlines()

            coord = None
            # Get program line
            trace_prefix = 'TURTLICO_TRACE:'
            if stderr_lines[0].startswith(trace_prefix):
                trace = stderr_lines[0][len(trace_prefix):].split(',')
                # Remove TURTLICO_TRACE from error message
                stderr_lines = stderr_lines[1:]
                for t in trace:
                    try:
                        python_line = int(t)
                    except Exception:
                        pass
                    finally:
                        t_coord = self._python_to_icons_coord(
                            debug_info, python_line)
                        if t_coord is not None:
                            coord = t_coord
                            break

            if coord is None:
                coord_msg = _('Error occured outside of your program.')
            else:
                coord_msg = _('Error occured on line {} column {}.').format(
                    coord[1] + 1, coord[0] + 1)

            self.error_message = '{}\n{}'.format(
                '\n'.join(stderr_lines), coord_msg)
        else:
            self.program_failed = False

    def _python_to_icons_coord(self,
                               debug_info: compiler.DebugInfo,
                               line: int) -> Union[Tuple[int, int], None]:
        coord = debug_info.get(line, None)
        if coord is not None:
            return coord
        for k in reversed(debug_info.keys()):
            if k < line:
                return debug_info[k]
        return None


def _get_python() -> str:
    platform = sys.platform
    if platform == 'win32':
        bindir = os.path.dirname(os.path.abspath(sys.argv[0]))
        python = os.path.join(bindir, 'pythonw.exe')
        return python
    return sys.executable


class Debugger(GObject.Object):
    debug_info: compiler.DebugInfo
    tempdir: tempfile.TemporaryDirectory  # Used for unsaved files
    path: str  # Path of the compiled file

    subprocpid: int  # PID of the process
    subprocpid_lock: threading.RLock

    @GObject.Property
    def running(self) -> bool:
        self.subprocpid_lock.acquire()
        running = self.subprocpid is not None
        self.subprocpid_lock.release()
        return running
    use_idle = GObject.Property(default=False, type=bool)

    @GObject.Signal(flags=GObject.SignalFlags.RUN_LAST,
                    arg_types=(DebuggingReuslt,))
    def debugging_done(self, *args):
        pass

    def __init__(self,
                 project: compiler.ProjectBuffer,
                 compiler: compiler.Compiler, *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.tempdir = None
        self.subprocpid = None
        self.subprocpid_lock = threading.RLock()

        code, debug_info = compiler.compile(project.code.lines)
        self.debug_info = debug_info
        utils.debug('Generated code:')
        utils.debug(code)

        self.path = None
        if project._project_file:
            self.path = project._project_file.get_path()
        else:
            self.tempdir = tempfile.TemporaryDirectory(prefix='turtlico_')
            self.path = os.path.join(self.tempdir.name, 'program.py')

        assert isinstance(self.path, str)
        with open(self.path, 'w') as f:
            f.write(code)

    def dispose(self):
        if self.tempdir:
            self.tempdir.cleanup()
        if self.props.running:
            self.stop()

    def run(self):
        if self.props.running:
            return
        # Sets something to subprocpid in order to prevent
        # from starting two threads at once
        self.subprocpid_lock.acquire()
        self.subprocpid = -1
        self.subprocpid_lock.release()

        self.props.running = True
        # The child program is run as a separate process due to safety reasons
        launcher = _launcher.format(self.path)

        args = [_get_python()]
        if self.props.use_idle:
            args.extend(['-m', 'idlelib', '-t', 'Turtlico'])
        args.extend(['-c', launcher])

        thread = threading.Thread(
            target=self._run_child, args=[args], daemon=True)
        thread.start()

    def stop(self):
        self.subprocpid_lock.acquire()
        assert self.props.running is True

        platform = sys.platform
        try:
            if platform == 'win32':
                os.kill(self.subprocpid, signal.CTRL_C_EVENT)
            else:
                os.kill(self.subprocpid, signal.SIGKILL)
        except Exception as e:
            utils.error(f'Cannot stop debugging: "{e}"')
        self.subprocpid_lock.release()

    def _run_child(self, args):
        self.subprocpid_lock.acquire()

        subproc = subprocess.Popen(
            args,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.subprocpid = subproc.pid

        self.subprocpid_lock.release()

        stdout, stderr = subproc.communicate()
        GLib.idle_add(self._run_child_done, stderr.decode('utf-8'))

    def _run_child_done(self, stderr: str) -> bool:
        self.subprocpid_lock.acquire()
        self.subprocpid = None
        self.subprocpid_lock.release()

        result = DebuggingReuslt(self.debug_info, stderr)

        self.emit('debugging-done', result)
        return GLib.SOURCE_REMOVE
