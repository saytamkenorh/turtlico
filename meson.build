project('turtlico', ['c', 'vala'],        version: '0.1.1',
  meson_version: '>= 0.40.0',
)

i18n = import('i18n')


subdir('data')
subdir('src')
subdir('po')
subdir('doc')

meson.add_install_script('build-aux/meson/postinstall.py')
