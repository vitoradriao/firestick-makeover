# Third-party notices

Firestick Makeover is MIT licensed (see [LICENSE](LICENSE)). It includes the following.

## FireFrame

The launcher in `launcher/` (the home screen, the Home button service, the updater) and the package
list in `debloat.txt` are derived from [FireFrame](https://github.com/dyascj/FireFrame), by CJ Dyas.
Firestick Makeover changed: the app name, package and icon; white logos cut out of each app's TV
banner when no bundled logo exists; app names hidden when a logo is shown; Home closing the app
drawer; the dock set over adb; the remote button remap (`ButtonService`); updates from this
repository's releases.

```
MIT License

Copyright (c) 2026 CJ Dyas

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Bundled assets

| Asset | Source | License |
| --- | --- | --- |
| Inter Medium and SemiBold (`launcher/assets/fonts`) | [rsms/inter](https://github.com/rsms/inter) | SIL Open Font License 1.1, see `launcher/assets/fonts/Inter-LICENSE.txt` |
| UI icons: image, grid_view, settings (`launcher/assets/ui`) | [Material Symbols](https://github.com/google/material-design-icons) | Apache License 2.0 |
| App logos (`launcher/assets/logos`) | [Simple Icons](https://github.com/simple-icons/simple-icons) | CC0 1.0. The logos are trademarks of their owners and only label their apps. |
| Wallpapers (`launcher/assets/wallpapers`) | [NASA Image and Video Library](https://images.nasa.gov) | Public domain (NASA media guidelines). NASA does not endorse this project. |

| Wallpaper | NASA ID | Caption |
| --- | --- | --- |
| aurora.jpg | [iss040e018989](https://images.nasa.gov/details/iss040e018989) | Aurora over Antarctica, ISS Expedition 40 |
| citylights.jpg | [iss058e005282](https://images.nasa.gov/details/iss058e005282) | Earth's limb with an aurora, ISS Expedition 58 |
| earthrise.jpg | [as17-152-23272](https://images.nasa.gov/details/as17-152-23272) | Earthrise over the Moon, Apollo 17 |
| southernlights.jpg | [iss067e133437](https://images.nasa.gov/details/iss067e133437) | Aurora over the South Pacific, ISS Expedition 67 |
| sunrise.jpg | [iss040e080833](https://images.nasa.gov/details/iss040e080833) | Sunrise over Earth's limb, ISS Expedition 40 |

## Downloaded at run time

`makeover.ps1` downloads Google's Android SDK Platform-Tools (adb) from `dl.google.com` after the
user agrees to the [Android SDK license](https://developer.android.com/studio/terms). It is not
redistributed here.

App logos cut out of TV banners are drawn on the device from apps the user installed; none are
included in this repository. Fire TV, Prime Video and the other service names are trademarks of
their owners. This project is not affiliated with Amazon or any streaming service.

## Firestick Makeover

```
MIT License

Copyright (c) 2026 Vitor Adrião

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
