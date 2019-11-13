pkgdocdir_abs = join_paths(get_option('prefix'), get_option('datadir'), 'doc', 'turtlico')
subdir('examples')

conf = configuration_data()
conf.set('VERSION', meson.project_version())
configure_file(
  input: 'conf.py.in',
  output: 'conf.py',
  configuration: conf,
)
configure_file(
  input: 'favicon.ico',
  output: 'favicon.ico',
  copy: true,
)

if get_option('help')

sphinx = find_program(['sphinx-build-3', 'sphinx-build'], required: true)

custom_target('en user documentation',
           command: [sphinx, '-b', 'html', '-c', meson.current_build_dir(), meson.current_source_dir(), '@OUTPUT@'],
            output: 'en',
build_always_stale: true,
  build_by_default: true
)

install_subdir(meson.current_build_dir() + '/en', install_dir: pkgdocdir_abs)

endif

