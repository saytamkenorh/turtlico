@echo off
set msys=C:\tools\msys64\
echo The MSYS2 directroy is set to: %msys%. If you need change this please visit build.bat file.
pause
%msys%/mingw64/bin/bash.exe -lc %CD%/build.sh