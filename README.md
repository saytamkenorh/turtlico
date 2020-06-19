## Turtlico
Turtlico is a programming tool for learning programming basics.<br>
It uses Python turtle so you can imagine a robotic turtle which is controled by your program.<br>
It also supports cycles, methods and many more. Turtlico also has a plugin for programming Raspberry Pi GPIO and a multimedia plugin.

For more information please visit the official [website](https://turtlico.gitlab.io).

## License
This program comes with ABSOLUTELY NO WARRANTY;
This is free software, and you are welcome to redistribute it
under certain conditions; see [COPYING](./COPYING) for details.

## Downloads
Turtlico supports Windows and Linux. <br>
**[Download the latest release on the official website](https://turtlico.gitlab.io/#downloads)**

<a href='https://flathub.org/apps/details/io.gitlab.Turtlico'><img width='240' alt='Download on Flathub' src='https://flathub.org/assets/badges/flathub-badge-i-en.png'/></a>

## Development

Development builds are available to download from [pipeline](https://gitlab.com/turtlico/turtlico/pipelines/latest).

**Building**

Please install following dependencies in order to compile Turtlico:

- `gee-0.8`
- `gtk+-3.0 >= 3.22`
- `gtksourceview-4`
- `json-glib-1.0`
- `meson >= 0.47.0`
- `vala`

To run programs created in Turtlico please install following:

- `python3`
- `python3-tk`
- `python3-gpiozero` (Rapspberry Pi plugin)
- `gir1.2-gstreamer-1.0` (Multimedia plugin)

Then just clone this repository, build and install the program:
	
```sh
git clone https://gitlab.com/turtlico/turtlico.git
cd turtlico
meson ./ ./build --prefix /usr/local
ninja -C build
sudo ninja -C build install
```
