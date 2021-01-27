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
import gettext
import locale

share_dir = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
localedir = os.path.join(share_dir, 'locale')

gettext.install('turtlico', localedir)
locale.setlocale(locale.LC_ALL, '')
locale.bindtextdomain('turtlico', localedir)
_ = gettext.gettext
