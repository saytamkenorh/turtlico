## Turtlico
Turtlico is a programming tool for learning programming basics.<br>
It uses Python turtle so you can imagine a robotic turtle which is controled by your program.<br>
It also supports cycles, methods and many more. Turtlico also has a plugin for programming Raspberry Pi GPIO and a multimedia plugin.

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
**Linux notes:**

If you are using the Linux version of Turtlico, you will need to install python3-tk and GStreamer (required for the multimedia plugin):

*Ubuntu and the other Debian-based distros:*

    sudo apt install python3-tk gir1.2-gstreamer-1.0
*Arch/Manjaro*

	sudo pacman -S python tk gst-python
*Fedora:*

    sudo dnf install python3-tk gstreamer-python
These packages are required for running programs created in Turtlico.

If you find issues with emoji rendering, make sure you have installed an emoji font.
Try running one of the following commands to fix that:

*Ubuntu and Raspbian/Debian (buster and newer)*

	sudo apt install fonts-noto-color-emoji
*Raspbian/Debian (stretch and older)*
	
	sudo apt install fonts-symbola
*Arch/Manjaro*
	
	sudo pacman -S noto-fonts-emoji
*Fedora*

	sudo dnf install google-noto-emoji-color-fonts
