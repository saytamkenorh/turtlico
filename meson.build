project(
  'turtlico',
  version: '1.0.0',
  meson_version: '>= 0.50.0',
)

i18n = import('i18n')
pkgdatadir = join_paths(get_option('prefix'), get_option('datadir'), meson.project_name())
modulesdir = join_paths(pkgdatadir, 'turtlico')

subdir('data')
install_subdir('turtlico', install_dir: pkgdatadir)
subdir('po')
subdir('doc')

python = import('python')

conf = configuration_data()
conf.set('PYTHON', python.find_installation('python3').path())

configure_file(
  input: 'turtlico.in',
  output: 'turtlico',
  configuration: conf,
  install: true,
  install_dir: get_option('bindir')
)

meson.add_install_script('build-aux/meson/postinstall.py')
