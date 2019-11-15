#!/bin/bash

projectname="turtlico"
projectid="tk.turtlico.Turtlico"
srcdir=$(pwd)/$line
builddir="$srcdir/build-portable/meson"
installdir="$srcdir/build-portable/install"

#build and install project
meson $srcdir $builddir --prefix $installdir || exit 1
ninja -C $builddir || exit 2
ninja -C $builddir install

#Creates AppImage directory
appdir="./$projectname.AppDir"
rm -rf $appdir
mkdir $appdir
#Copy desktop integration files
cp "$installdir/share/applications/$projectid.desktop" $appdir/$projectname.desktop
cp "$installdir/share/icons/hicolor/48x48/apps/$projectid.png" $appdir/$projectname.png
cp "$installdir/share/icons/hicolor/256x256/apps/$projectid.png" $appdir/$projectid.png
#Copy app files
mkdir $appdir/usr
cp -r $installdir/* $appdir/usr

#Make AppRun
cat > $appdir/AppRun <<\EOF
#!/bin/sh
HERE=$(dirname $(readlink -f "${0}"))
export PATH="${HERE}/usr/bin":$PATH
export LD_LIBRARY_PATH="${HERE}/usr/lib/":$LD_LIBRARY_PATH
export XDG_DATA_DIRS="${HERE}/usr/share/":$XDG_DATA_DIRS
cd "${HERE}/usr/bin"
exec "turtlico" $@
EOF
chmod a+x $appdir/AppRun

#Download and run AppImage tool
if [ ! -f ./appimagetool-x86_64.AppImage ]; then
    wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage ./appimagetool-x86_64.AppImage
	chmod +x ./appimagetool-x86_64.AppImage
fi
arch=x86_64
ARCH=$arch ./appimagetool-x86_64.AppImage --no-appstream $appdir $projectname-$arch.AppImage || exit 3

#remove temp files and cd to default dir
rm -rf ./build-portable
