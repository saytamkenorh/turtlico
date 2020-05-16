MINGW_PREFIX=mingw-w64-x86_64
# Compile dependencies. Packages that are then bundled to distribution are contained in pkglist.txt file.
BUILD_DEPS="desktop-file-utils gcc meson pkg-config vala"
srcdir=$(dirname $0)
cd $srcdir

pacman -Syu --noconfirm
pacman -Su --noconfirm
pkglist=$(cat ./pkglist.txt | sed ':a;N;$!ba;s/\n/ /g')
pkglist="$pkglist $BUILD_DEPS"
pkglist=$(echo $pkglist | sed "s/[^ ]* */$MINGW_PREFIX-&/g")
pkglist="tar $pkglist" # Packages required for this script
pacman -S $pkglist --needed --noconfirm

rm -rf ./build

# Workarouds
# Disable appstream file (its issue)
if grep -q appstream_file "../data/meson.build"; then
  sed -i -e '18,32d' ../data/meson.build
fi
sed -i 's/^M$//' ./PKGBUILD

MINGW_INSTALLS=mingw64 makepkg-mingw -sCf

echo "Bundling runtime. This will take a while."
rm -rf ./output

# Copy library stack
./deploy.sh "$srcdir/output" $MINGW_PREFIX || exit 1
# Add it to PATH
bindir=$(echo "$srcdir/output/bin" | sed -e "s-C:/-/c/-g")
export PATH="$bindir:$PATH"

"$bindir/gdk-pixbuf-query-loaders.exe" > "$srcdir/output/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"

echo "Removing useless stuff..."
rm -rf "$srcdir/output/share/icons/hicolor/"*/apps
# Useless Adwaita icons
rm -rf "$srcdir/output/share/icons/Adwaita/cursors"
rm -rf "$srcdir/output/share/icons/Adwaita/"*/apps
rm -rf "$srcdir/output/share/icons/Adwaita/"*/categories
rm -rf "$srcdir/output/share/icons/Adwaita/"*/devices
rm -rf "$srcdir/output/share/icons/Adwaita/"*/emblems
rm -rf "$srcdir/output/share/icons/Adwaita/"*/emotes
rm -rf "$srcdir/output/share/icons/Adwaita/"*/status
rm -rf "$srcdir/output/share/icons/Adwaita/"*/legacy/face*
rm -rf "$srcdir/output/share/icons/Adwaita/"*/legacy/battery*
rm -rf "$srcdir/output/share/icons/Adwaita/"*/legacy/network*
rm -rf "$srcdir/output/share/icons/Adwaita/"*/legacy/weather*
# Sizes that are not used often
rm -rf "$srcdir/output/share/icons/Adwaita/256x256"
rm -rf "$srcdir/output/share/icons/Adwaita/512x512"
# Other useless stuff
rm -rf "$srcdir/output/bin/gtk3-"*
find "$srcdir/output/bin" -not -name "g*" -name "*.exe" -not -name "*python*" -not -name "update-mime-database.exe" -exec rm -f {} \;
rm -rf "$srcdir/output/share/aclocal"
rm -rf "$srcdir/output/share/applications"
rm -rf "$srcdir/output/share/bash-completion"
rm -rf "$srcdir/output/share/doc"
rm -rf "$srcdir/output/share/gdb"
rm -rf "$srcdir/output/share/gdb"
rm -rf "$srcdir/output/share/graphite2"
rm -rf "$srcdir/output/share/gir-1.0"
rm -rf "$srcdir/output/share/gtk-doc"
rm -rf "$srcdir/output/share/installed-tests"
rm -rf "$srcdir/output/share/info"
rm -rf "$srcdir/output/share/man"
rm -rf "$srcdir/output/share/mime"
rm -rf "$srcdir/output/share/vala"
rm -rf "$srcdir/output/lib/cmake"
rm -rf "$srcdir/output/lib/python2.7"
rm -rf "$srcdir/output/lib/python3.8/test"
rm -rf "$srcdir/output/lib/pkgconfig"
rm -rf "$srcdir/output/lib/tk8.6/demos"
#rm -rf "$srcdir/output/lib/girepository-1.0"
find "$srcdir/output/lib/python3.8" -name "*.pyc" -exec rm -f {} \;
find "$srcdir/output/lib" -name "*.a" -exec rm -f {} \;
find "$srcdir/output/share/locale/"* -maxdepth 0 -not -name "cs" -not -name "en*" -exec rm -rf {} \;

# Bundles turtlico
echo "Extracting Turtlico package to output directory..."
cd $srcdir
tmp=`mktemp -d`
tar -I zstd -xf ./mingw-w64-x86_64-turtlico-* -C $tmp
cd $tmp
cp -r $PWD/mingw64/bin "$srcdir/output"
cp -r $PWD/mingw64/share "$srcdir/output"
cd $srcdir
rm -rf $tmp

# Post-inst procedures
glib-compile-schemas "$srcdir/output/share/glib-2.0/schemas"
rm "$srcdir/output/bin/glib-compile-schemas.exe"
"$bindir/update-mime-database.exe" "$srcdir/output/share/mime"
rm "$srcdir/output/bin/update-mime-database"*

# Create ISS file
rootdir=$(dirname $srcdir) # Get the root dir of the project
sed 's~@PROJECT_DIR@~'$rootdir'~g' "$rootdir/windows/turtlico.iss" > "$rootdir/windows/build/turtlico.iss"