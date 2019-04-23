#! /usr/bin/env sh
export LANG=en_US.utf8

if [ "$#" -ne 2 ];
then
  printf "Usage: ./deploy.sh exe directory\n"
fi

list=$(ldd $1 | grep /mingw64 | sed 's/.dll.*/.dll/')
list="$list python3.exe tcl86.dll tk86.dll"
#list="$list /min"
for dll in $list;
do
  pkg=`pacman -Qo $dll | sed 's/.* is owned by //' | tr ' ' '-'`
  pkglist="$pkglist $pkg"
done
# remove duplicates
pkglist=`echo $pkglist | tr ' ' '\n' | sort | uniq`
printf "$pkglist\n"

mkdir -p "$2"

tmp=`mktemp -d`
cd $tmp

for pkg in $pkglist
do
  tar -xf /var/cache/pacman/pkg/$pkg-any.pkg.tar.xz
  # more fine-grained control is possible here
done
tar -xf /var/cache/pacman/pkg/mingw-w64-x86_64-adwaita*-any.pkg.tar.xz

cp -r $PWD/mingw64/bin $2
cp -r $PWD/mingw64/share $2
cp -r $PWD/mingw64/lib $2