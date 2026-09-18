# PepoConnect

**Take a photo on your phone. See it on your computer. Keep the ones you want.**

PepoConnect moves photos, videos, files and clipboard text between your devices
over your local network. No accounts, no emailing files to yourself, and no
uploading your files to a cloud. It covers the photo and file-sharing part of
Intel Unison, with support for Windows, Linux, Android and iPhone.

[Download](https://github.com/pepitolas13/PepoConnect/releases/latest) ·
[What's new in 0.4](https://github.com/pepitolas13/PepoConnect/releases/tag/v0.4.0) ·
[Español](README.md)

If PepoConnect is useful to you, a **⭐** is a welcome way to support it.
Found a problem? [Tell us what happened](https://github.com/pepitolas13/PepoConnect/issues/new/choose).

![Your phone's gallery on your computer](docs/screenshots/galeria.png)

## Get started

1. Install PepoConnect on both devices and connect them to the same network.
2. Scan the computer's QR code with your phone, or use the six-digit pairing code.
3. Browse your phone's gallery or drag a file onto a paired device. Devices you
   have already paired reconnect automatically.

| Platform | Download |
|---|---|
| Windows 10/11, 64-bit | [Single executable](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-win-x64.exe) · [Portable ZIP](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-win-x64-portable.zip) |
| Android | [ARM64 APK](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-android-arm64-v8a.apk) · [Universal ARM APK](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-android-universal.apk) |
| Linux x64 | [AppImage](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-linux-x64.AppImage) · [Flatpak](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-linux-x64.flatpak) · [tar.gz](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-linux-x64.tar.gz) |
| Linux ARM64 | [AppImage](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-linux-arm64.AppImage) · [Flatpak](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-linux-arm64.flatpak) · [tar.gz](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-linux-arm64.tar.gz) |
| iPhone | [Unsigned IPA](https://github.com/pepitolas13/PepoConnect/releases/latest/download/PepoConnect-ios-unsigned.ipa), installed through AltStore or Sideloadly |

The release page also includes 32-bit ARM and x86_64 Android builds. Android
asks for permission to install downloaded APKs. The iPhone version requires
sideloading and is not an App Store download.

## What you can do

- Browse your phone's gallery from your computer and download original files.
- See newly taken photos while the devices are connected.
- Send files in both directions, resume interrupted transfers and connect
  several devices at once.
- Share clipboard text. Android background clipboard restrictions still apply;
  use its quick-settings tile, app shortcut or share menu when needed.
- Send a file to someone through a one-use browser link, without installing
  the app on the receiving device.
- Check for updates daily and install them from Settings → About. Automatic
  foreground notices can be disabled independently.

Windows and Linux AppImage/tarball updates restart the app. Android requires
its system installer confirmation; Flatpak opens the system software manager.
An unsigned iPhone IPA must be reinstalled with the same signing account.
Install 0.4 once manually if you are upgrading from an older version: subsequent
versions can use the new updater.
On Windows and Linux, close the previous version before opening the new download.
On Android, install the APK over the existing app to keep your data.

## Privacy and development

Files and pairing stay on your local network. Transfers between paired apps
use encrypted connections. Temporary guest links opened in a browser use
unencrypted HTTP on the local network; use those links only on a trusted network.
Update checks contact GitHub; packages are downloaded when you choose to update
and checked against the release's SHA-256 manifest.

The app uses Flutter and a Rust transfer engine. See [build instructions](README.md#compilar),
[packaging details](docs/packaging.md) and [how to contribute](CONTRIBUTING.md).

## License

Copyright © 2026 PepoTech ([pepitolas13](https://github.com/pepitolas13)).
PepoConnect's own code is licensed under the [GNU GPL version 3](LICENSE)
(`GPL-3.0-only`). You may use, modify and redistribute it, including commercially.
If you distribute a modified version, you must provide its source under GPLv3
and preserve the copyright notices. Third-party code keeps its own licenses.
