subdir('icons')

desktop_file = i18n.merge_file(
  input: 'io.gitlab.Turtlico.desktop.in',
  output: 'io.gitlab.Turtlico.desktop',
  type: 'desktop',
  po_dir: '../po',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications')
)

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test('Validate desktop file', desktop_utils,
    args: [desktop_file]
  )
endif

appstream_file = i18n.merge_file(
  input: 'io.gitlab.Turtlico.appdata.xml.in',
  output: 'io.gitlab.Turtlico.appdata.xml',
  po_dir: '../po',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'appdata')
)

if get_option('appstream')
  appstream_util = find_program('appstream-util', required: false)
  if appstream_util.found()
    test('Validate appstream file', appstream_util,
      args: ['validate', appstream_file]
    )
  endif
endif

install_data('io.gitlab.Turtlico.gschema.xml',
  install_dir: join_paths(get_option('datadir'), 'glib-2.0/schemas')
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('Validate schema file', compile_schemas,
    args: ['--strict', '--dry-run', meson.current_source_dir()]
  )
endif

install_data('io.gitlab.Turtlico.xml',
	     install_dir : join_paths(get_option('datadir'),'mime/packages'))

gnome = import('gnome')

resource_files = files('turtlico.gresource.xml')
gnome.compile_resources('io.gitlab.Turtlico',
  resource_files,
  gresource_bundle: true,
  install: true,
  install_dir: pkgdatadir,
)
