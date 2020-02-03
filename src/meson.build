turtlico_sources = [
  'app-settings.vala',
  'command.vala',
  'compiler.vala',
  'debugger.vala',
  'main.vala',
  'package-service.vala',
  'program-buffer.vala',
  'program-settings.vala',
  'programview.vala',
  'search-widget.vala',
  'window.vala',
]

if build_machine.system() == 'windows'
  win = import('windows')
  turtlico_sources += win.compile_resources('turtlico.rc')
endif

turtlico_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('gee-0.8', version: '>= 0.18'),
  dependency('json-glib-1.0', version: '>= 1.0'),
  dependency('gtksourceview-4', version: '>= 4.0'),
]

gnome = import('gnome')

turtlico_sources += gnome.compile_resources('turtlico-resources',
  'turtlico.gresource.xml',
  c_name: 'turtlico'
)

subdir('icons')

localedir = join_paths(get_option('prefix'), get_option('localedir'))

add_project_arguments(['-DGETTEXT_PACKAGE="turtlico"',
  '-DLOCALE_DIR="' + localedir + '"',
  '-DTURTLICO_VERSION="' + meson.project_version() + '"'], language: 'c')

if turtlico_deps[1].version() > '3.22.20'
   add_project_arguments(['-D', 'TURTLICO_EMOJI_HINT'], language: 'vala')
endif

if get_option('flatpak')
   add_project_arguments(['-D', 'TURTLICO_FLATPAK'], language: 'vala')
endif
if get_option('flatpak-no-sandbox')
   add_project_arguments(['-D', 'TURTLICO_FLATPAK_NO_SANDBOX'], language: 'vala')
endif

if target_machine.system() == 'windows'
   add_project_arguments(['-D', 'WINDOWS'], language: 'vala')
endif

if target_machine.system() == 'linux'
   add_project_arguments(['-D', 'LINUX'], language: 'vala')
endif

turtlico_executable = executable('turtlico', turtlico_sources,
  vala_args: '--target-glib=2.50',  dependencies: turtlico_deps,
  install: true,
)
