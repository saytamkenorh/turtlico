## Turtlico
Turtlico is a programming tool for learning programming basics.<br>
It uses Python turtle so you can imagine a robotic turtle which is controled by your program.<br>
It also supports cycles, methods and many more. Turtlico also has a plugin for programming Raspberry Pi GPIO and a multimedia plugin.

For more information please visit the official [website](https://turtlico.tk).

## License
This program comes with ABSOLUTELY NO WARRANTY;
This is free software, and you are welcome to redistribute it
under certain conditions; see [COPYING](./COPYING) for details.

## Downloads
Turtlico supports Windows and Linux. <br>
**[Download the latest release on the official website](https://turtlico.tk/#downloads)**

<a href='https://flathub.org/apps/details/tk.turtlico.Turtlico'><img width='240' alt='Download on Flathub' src='https://flathub.org/assets/badges/flathub-badge-i-en.png'/></a>

Or clone this repository and build the program yourself:
	
	meson ./ ./build --prefix /usr/local
	cd ./build
	ninja && sudo ninja install
