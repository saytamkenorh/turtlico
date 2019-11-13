python = find_program('python3')
test = find_program('test')

test ('Compile examples', test, args:[turtlico_executable.full_path(), meson.current_source_dir(), python.path(), meson.current_build_dir()])

if get_option('help')
pkgdocexamplesdir_abs = join_paths(get_option('prefix'), get_option('datadir'), 'doc', 'turtlico', 'en', 'examples')

example_files = [
	'calc.tcp',
	'color.tcp',
	'direct-python.tcp',
	'files.tcp',
	'files-write-input.tcp',
	'image.tcp',
	'image.gif',
	'keyboard-mouse.tcp',
	'random-move.tcp',
	'sound-player.tcp',
	'turtle-star.tcp',
]

install_data(
	example_files,
	install_dir: pkgdocexamplesdir_abs)
endif
