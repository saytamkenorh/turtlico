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
**[Download the latest release](https://turtlico.tk/#downloads)**

Or clone this repository and build the program yourself:
	
	meson ./ ./build --prefix /usr/local
	cd ./build
	ninja && sudo ninja install
**Linux notes:**

If you would like to use the Linux version of Turtlico, you will need to install [Flatpak](https://flatpak.org/) and add the [Flathub](https://flathub.org/about) remote.

So please follow **[these instructions](https://flatpak.org/setup)** before installing Turtlico.
