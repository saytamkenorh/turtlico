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

**Building on Linux**

The recommend way of building Turtlico is using Flatpak.

In order to create a bundle run in the directory of the repository following commands:

```sh
flatpak-builder --repo=./.flatpak/repo --force-clean _build io.gitlab.Turtlico.json
flatpak build-bundle ./.flatpak/repo turtlico.flatpak io.gitlab.Turtlico.json
```
You can also use IDEs like VS Code or GNOME Builder with Flatpak integration.

**Building on Windows**

Turtlico Windows build dependencies can be obtained from [Chocolatey](https://chocolatey.org/install). Then you can run the build script:

```powershell
choco install msys2 -y
cd .\windows
filter replace-slash {$_ -replace "\\", "/"}
C:\tools\msys64\usr\bin\bash.exe -lc "$(Get-Location | replace-slash)/build.sh"
```

You can also create an installer:

```
choco install innosetup -y
iscc .\build\turtlico.iss /Q /O$(Get-Location) /Fturtlico-setup.exe
```