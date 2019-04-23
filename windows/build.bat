@echo off
set msys=S:\msys64\
echo The MSYS2 directroy is set to: %msys%. If you need change this visit build.bat file.
pause
%msys%/mingw64.exe ./build.sh %msys%