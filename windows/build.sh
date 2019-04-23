pacman -Syu
pacman -Su
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-pkg-config mingw-w64-x86_64-vala \
mingw-w64-x86_64-meson mingw-w64-x86_64-gtk3 mingw-w64-x86_64-gettext mingw-w64-x86_64-desktop-file-utils \
mingw-w64-x86_64-libgee --needed
srcdir=$(pwd)/$line
rm -rf ./build

# Workarouds
# Disable appstream file (its issue)
if grep -q appstream_file "../data/meson.build"; then
  sed -i -e '18,32d' ../data/meson.build
fi

pacman -R mingw-w64-x86_64-turtlico
MINGW_INSTALLS=mingw64 makepkg-mingw -sCf
pacman -U "$srcdir"*.tar.xz --force

echo Bundling runtime. This will take a while.
rm -rf ./output
./deploy.sh /mingw64/bin/turtlico.exe "$srcdir/output"

mkdir "$srcdir/output/lib"
cp -r $1/mingw64/lib/gdk-pixbuf-2.0 "$srcdir/output/lib"
gdk-pixbuf-query-loaders > "$srcdir/output/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
glib-compile-schemas "$srcdir/output/share/glib-2.0/schemas"
update-mime-database "$srcdir/output/share/mime"

# Useless Adwaita icons
rm -rf "$srcdir/output/share/icons/Adwaita/cursors"
rm -rf "$srcdir/output/share/icons/Adwaita/"*/apps
# Sizes that are not used often
rm -rf "$srcdir/output/share/icons/Adwaita/256x256"
rm -rf "$srcdir/output/share/icons/Adwaita/512x512"
# Other useless stuff
rm -rf "$srcdir/output/bin/gtk3-"*
find "$srcdir/output/bin" -not -name "g*.exe" -name "*.exe" -not -name "*python*" -not -name "update*.exe" -exec rm -f {} \;
rm -rf "$srcdir/output/share/doc"
rm -rf "$srcdir/output/share/gtk-doc"
rm -rf "$srcdir/output/lib/python3.7/test"
find "$srcdir/output/lib/python3.7" -name "*.pyc" -exec rm -f {} \;
find "$srcdir/output/lib" -name "*.a" -exec rm -f {} \;
find "$srcdir/output/share/locale/"* -maxdepth 0 -not -name "cs" -not -name "en*" -exec rm -rf {} \;
# Bundles turtlico
tmp=`mktemp -d`
cd $tmp
tar -xf $srcdir/mingw-w64-x86_64-turtlico-1.0-1-any.pkg.tar.xz
cp -r $PWD/mingw64/bin "$srcdir/output"
cp -r $PWD/mingw64/share "$srcdir/output"

cd $srcdir

read -n1 -r -p "Press any key to continue..." key
