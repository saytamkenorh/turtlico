MINGW_ARCH=64
MINGW_PREFIX=mingw-w$MINGW_ARCH-x86_64
BUILD_DEPS="desktop-file-utils meson pkgconf"
RUNTIME_DEPS="gtk4 python python-gobject"
BUNDLE_BLACKLIST="gst-plugins-bad sqlite3"

install_deps () {
	echo "Installing dependencies..."
	pacman -S tar --needed --noconfirm

	pacman -S $RUNTIME_DEPS --assume-installed="$BUNDLE_BLACKLIST" --needed --noconfirm
	pacman -S $BUILD_DEPS --needed --noconfirm
	paccache -rk 1
}

list_deps_for () {
	if [[ " ${BUNDLE_BLACKLIST[@]} " =~ " $1 " ]]; then
		return
	fi
	if [[ " ${list_deps_pkgs[@]} " =~ " $1 " ]]; then
		return
	fi
	list_deps_pkgs="$list_deps_pkgs $1"
	local deps="$(pactree -u -d 1 $1)"
	local pkg
	for pkg in $deps
	do
		list_deps_for $pkg
	done
}

extract_packages () {
	local pkg
	list_deps_pkgs=""
	for pkg in $1
	do
		list_deps_for $pkg
	done	

	pkgs=$(echo $list_deps_pkgs | sort -u | xargs -n 1 pacman -Sp | awk -F// '{print $NF}')

	for pkg in $pkgs
	do
		echo "Bundling '$pkg'"
		tarcmd=""
		if [[ $pkg == *.tar.zst ]]; then
			tarcmd="tar -I zstd"
		elif [[ $pkg == *.tar.xz ]]; then
			tarcmd="tar"
		else
			echo "Unknown package format."
			exit 1
		fi
		$tarcmd --strip-components=1 -C $2 -xf $pkg mingw64/bin &>/dev/null
		$tarcmd --strip-components=1 -C $2 -xf $pkg mingw64/share &>/dev/null
		$tarcmd --strip-components=1 -C $2 -xf $pkg mingw64/lib &>/dev/null
	done
}

cleanup () {
	# Binaries
	find "$1/bin/" -type f -not -name "*.dll" -not -name "python*" -not -name "turtlico" -not -name "gspawn*" -delete
	
	rm -rf "$1/share/aclocal"
	rm -rf "$1/share/applications"
	rm -rf "$1/share/appdata"
	rm -rf "$1/share/bash-completion"
	rm -rf "$1/share/doc"
	rm -rf "$1"/share/gettext*
	rm -rf "$1/share/gdb"
	rm -rf "$1/share/graphite2"
	rm -rf "$1/share/gtk-doc"
	rm -rf "$1/share/installed-tests"
	rm -rf "$1/share/info"
	rm -rf "$1/share/man"
	rm -rf "$1/share/mime"
	rm -rf "$1/share/metainfo"
	rm -rf "$1/lib/pkgconfig"
	rm -rf "$1/lib/tk8.6/demos"
	rm -rf "$1/share/vala"
	rm -rf "$1/share/terminfo"
	rm -rf "$1/share/p11-kit"
	rm -rf "$1/share/pki"
	rm -rf "$1/share/thumbnailers"
	rm -rf "$1/share/xml"

	rm -rf "$1"/lib/engines*
	rm -rf "$1"/lib/python2.*
	rm -rf "$1"/lib/python3.*/test
	rm -rf "$1/lib/terminfo"
	rm -rf "$1/lib/gettext"

	# Adwaita icons that are not used
	rm -rf "$1/share/icons/Adwaita/96x96"
	rm -rf "$1/share/icons/Adwaita/256x256"
	rm -rf "$1/share/icons/Adwaita/512x512"
	rm -rf "$1/share/icons/Adwaita/cursors"
	# Unused translations
	find "$1/share/locale/"* -maxdepth 0 -not -name "cs" -not -name "en*" -not -name "de" -exec rm -rf {} \;
	
	# Files
	find "$1" -name "*.a" -exec rm -f {} \;
	find "$1" -name "*.whl" -exec rm -f {} \;
	find "$1" -name "*.h" -exec rm -f {} \;
	find "$1" -name "*.la" -exec rm -f {} \;
	find "$1" -name "*.sh" -exec rm -f {} \;
	find "$1" -name "*.jar" -exec rm -f {} \;
	find "$1" -name "*.def" -exec rm -f {} \;
	find "$1" -name "*.cmd" -exec rm -f {} \;
	find "$1" -name "*.cmake" -exec rm -f {} \;
	find "$1" -name "*.pc" -exec rm -f {} \;
	find "$1" -name "*.desktop" -exec rm -f {} \;
	find "$1" -name "*.manifest" -exec rm -f {} \;
	find "$1" -name "*.pyc" -exec rm -f {} \;
	
	"$1/bin/python3.exe" "$src_dir/depcheck.py" --delete

	find "$1" -type d -empty -delete
}

# Parse config
# Adds mingw prefix to package lists
BUILD_DEPS=$(echo $BUILD_DEPS | sed "s/[^ ]* */$MINGW_PREFIX-&/g")
RUNTIME_DEPS=$(echo $RUNTIME_DEPS | sed "s/[^ ]* */$MINGW_PREFIX-&/g")
BUNDLE_BLACKLIST=$(echo $BUNDLE_BLACKLIST | sed "s/[^ ]* */$MINGW_PREFIX-&/g")

export LC_ALL="C"
export PATH="/mingw$MINGW_ARCH/bin:$PATH"

# Installs required packages
install_deps

src_dir=$(dirname $0)
build_dir="$src_dir/build"
output_dir=$(echo "$build_dir/output" | sed -e "s-C:/-/c/-g")
output_bin_dir="$output_dir/bin"

rm -rf "$build_dir"
mkdir "$build_dir"
mkdir "$output_dir"

# Build package
echo "Building Turtlico..."
sed 's/^M//' "$src_dir/src/PKGBUILD.in" > "$src_dir/build/PKGBUILD"
cd "$src_dir/build"
MINGW_INSTALLS=mingw$MINGW_ARCH makepkg-mingw --cleanbuild --force --noconfirm || exit 1

# Bundles turtlico
echo "Extracting Turtlico package to output directory..."
cd $build_dir
tar -I zstd --strip-components=3 -xf ./$MINGW_PREFIX-turtlico-* -C $output_dir tools/msys64/mingw64

# Bundle all the stuff
echo "Bundling dependencies. This will take a while..."
extract_packages "$RUNTIME_DEPS" "$output_dir"

# Post-inst procedures
"$output_bin_dir/gdk-pixbuf-query-loaders.exe" > "$output_dir/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
"$output_bin_dir/gtk4-update-icon-cache.exe" "$output_dir/share/icons/Adwaita"
"$output_bin_dir/gtk4-update-icon-cache.exe" "$output_dir/share/icons/hicolor"
"$output_bin_dir/glib-compile-schemas.exe" "$output_dir/share/glib-2.0/schemas" || exit 1

echo "Removing useless stuff..."
cleanup $output_dir

# Compile Turtlico launcher
echo "Compiling Turtlico launcher..."
windres "$src_dir/src/turtlico.rc" -O coff -o "$build_dir/turtlico.res"
gcc -mwindows "$src_dir/src/turtlico.c" "$build_dir/turtlico.res" -o "$output_bin_dir/turtlico.exe" $(pkg-config --cflags --libs glib-2.0)

echo -n "Compiling test file..."
"$output_bin_dir/turtlico.exe" --compile="/dev/null" "$src_dir/../doc/examples/turtle-star.tcp"
result="$?"
if [[ result -eq 0 ]]; then
	echo "OK"
else
	echo "FAILED"
	exit 1
fi

# Create ISS file
echo "Creating ISS file..."
rootdir=$(dirname $src_dir) # Get the root dir of the project
version=$(cat "$rootdir/meson.build" | sed -n "s/ version:\(.*\)/\1/p" |  cut -d \' -f2)
sed "s~@PROJECT_DIR@~$rootdir~g; s~@PROJECT_VERSION@~$version~g" "$src_dir/src/turtlico.iss" > "$build_dir/turtlico.iss"