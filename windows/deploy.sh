#! /usr/bin/env sh
export LANG=en_US.utf8

paccache -rk 1 # Keep only the latest version of packages in cache

mkdir -p "$1"
pkglist=$(cat ./pkglist.txt | sed ':a;N;$!ba;s/\n/ /g')

tmp=`mktemp -d`
cd $tmp

# Extract
for pkg in $pkglist
do
  version=$(pacman -Qi $2-$pkg | grep Version | uniq |  awk '{print $3}')
  echo $2-$pkg-$version
  tar -xf /var/cache/pacman/pkg/$2-$pkg-$version-any.pkg.tar.xz
done
echo "Moving files to the output directory..."
mv $PWD/mingw64/bin $1
mv $PWD/mingw64/share $1
mv $PWD/mingw64/lib $1

echo "Removing temp folder..."
rm -rf $tmp