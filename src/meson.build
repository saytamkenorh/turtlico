turtlico_sources = [
  'main.vala',
  'window.vala',
  'programview.vala',
  'command.vala',
  'compiler.vala',
  'program-settings.vala',
  'app-settings.vala',
]

turtlico_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('gee-0.8', version: '>= 0.18'),
  dependency('json-glib-1.0', version: '>= 1.0'),
]

gnome = import('gnome')

turtlico_sources += gnome.compile_resources('turtlico-resources',
  'turtlico.gresource.xml',
  c_name: 'turtlico'
)

localedir = join_paths(get_option('prefix'), get_option('localedir'))

add_project_arguments(['-DGETTEXT_PACKAGE="turtlico"',
  '-DLOCALE_DIR="' + localedir + '"',
  '-DTURTLICO_VERSION="' + meson.project_version() + '"'], language: 'c')

if turtlico_deps[1].version() > '3.22.20'
	add_project_arguments(['-D', 'TURTLICO_EMOJI_HINT'], language: 'vala')
endif

turtlico_executable = executable('turtlico', turtlico_sources,
  vala_args: '--target-glib=2.50',  dependencies: turtlico_deps,
  install: true,
)
