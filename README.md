## Turtlico
Turtlico is a programming tool for learning programming basics.<br>
It uses Python turtle so you can imagine a robotic turtle which is controled by your program.<br>
It also supports cycles, methods and many more. Turtlico also has a plugin for programming Raspberry Pi GPIO.

## License
This program comes with ABSOLUTELY NO WARRANTY;
This is free software, and you are welcome to redistribute it
under certain conditions; see [COPYING](./COPYING) for details.

## Downloads
Turtlico supports Windows and Linux. <br>
**[Download the latest release](https://gitlab.com/matyas5/turtlico/tags)**

Or clone this repository and build the program yourself:
	
	meson ./ ./build --prefix /usr/local
	cd ./build
	ninja && sudo ninja install
**Linux AppImage notes:**
If you are using the AppImage version of Turtlico, you will need to install python3-tk (if you haven't done yet):
*Ubuntu and other Debian-based distros:*

    sudo apt install python3-tk
*Fedora:*

    sudo dnf install python3-tk
If you find issues with emoji rendering, make sure you have installed an emoji font.
Try running one of the following commands to fix that:
*Ubuntu and Debian (buster and newer)*

	sudo apt install fonts-noto-color-emoji
*Raspbian/Debian (stretch and older)*
	
	sudo apt install fonts-symbola

