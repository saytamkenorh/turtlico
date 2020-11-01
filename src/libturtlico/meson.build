libturtlico_sources = [
   'command.vala',
   'compiler.vala',
]

libturtlico_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('gee-0.8', version: '>= 0.18'),
  dependency('json-glib-1.0', version: '>= 1.0'),
]

libturtlico = shared_library('turtlico', libturtlico_sources,
                  vala_header: 'libturtlico.h',
                  vala_gir: 'Turtlico-0.0.gir',
                  dependencies: libturtlico_deps,
                  install: true,
                  install_dir: [true, true, true, true])

g_ir_compiler = find_program('g-ir-compiler')
custom_target(
  'libturtlico typelib',
  output: 'Turtlico-0.0.typelib',
  command: [g_ir_compiler, '--shared-library', 'libturtlico', '--output', '@OUTPUT@', meson.current_build_dir() / 'Turtlico-0.0.gir'],
  depends: libturtlico,
  install: true,
  install_dir: get_option('libdir') / 'girepository-1.0',
)

libturtlico_dep = declare_dependency(
	link_with: libturtlico,
	include_directories: include_directories('.')
)
