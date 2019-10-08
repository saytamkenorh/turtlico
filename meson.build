project('turtlico', ['c', 'vala'],        version: '0.1.5',
  meson_version: '>= 0.47.0',
)

i18n = import('i18n')


subdir('data')
subdir('src')
subdir('po')
subdir('doc')

meson.add_install_script('build-aux/meson/postinstall.py')
