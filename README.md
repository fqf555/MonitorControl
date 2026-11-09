> **Unofficial fork — Qifeng's MonitorControl**
>
> This is an independently maintained fork of [MonitorControl](https://github.com/MonitorControl/MonitorControl), not an official release from the upstream project. Credit for the original app belongs to the MonitorControl maintainers and contributors. This fork adds a modern glass HUD and continuous keyboard adjustment, with its own releases and update feed.
>
> **[Download this fork](https://github.com/fqf555/MonitorControl/releases/latest)** · [Original project and official releases](https://github.com/MonitorControl/MonitorControl). The README below is adapted from upstream and retains links to its releases, documentation, and community.

<img src=".github/Icon-cropped.png" width="200" alt="App icon" align="left"/>

<div>
<h3>MonitorControl</h3>
<p>Controls your external display brightness and volume and shows native OSD.
Use menubar extra sliders or the keyboard, including native Apple keys!</p>
<a href="https://github.com/MonitorControl/MonitorControl/releases"><img src=".github/macos_badge_noborder.png" width="175" alt="Download for macOS"/></a>
</div>

<br/><br/>

<div align="center">
<a href="https://github.com/MonitorControl/MonitorControl/releases"><img src="https://img.shields.io/github/downloads/MonitorControl/MonitorControl/total.svg?style=flat" alt="downloads"/></a>
<a href="https://github.com/MonitorControl/MonitorControl/releases"><img src="https://img.shields.io/github/release-pre/MonitorControl/MonitorControl.svg?style=flat" alt="latest version"/></a>
<a href="https://github.com/MonitorControl/MonitorControl/blob/master/License.txt"><img src="https://img.shields.io/github/license/MonitorControl/MonitorControl.svg?style=flat" alt="license"/></a>
<a href="https://github.com/MonitorControl/MonitorControl"><img src="https://img.shields.io/badge/platform-macOS-blue.svg?style=flat" alt="platform"/></a>

<br/>
<br/>

<img src=".github/screenshot.png" width="824" alt="Screenshot"/><br/>

</div>

<hr>

## Download

### Qifeng's fork (Apple Silicon)

Download the signed and notarized build from [fqf555/MonitorControl releases](https://github.com/fqf555/MonitorControl/releases/latest). Unzip it, quit any running MonitorControl, and move `MonitorControl.app` to Applications. This fork checks its own GitHub Releases appcast for future updates, not the upstream feed. The first migration from the upstream app must be installed manually. If Accessibility shows enabled but keyboard control is denied, remove the old MonitorControl entry and add the new app again because the signing identity has changed. This release requires an Apple Silicon Mac and macOS 12 or newer.

### Upstream releases

Go to [Releases](https://github.com/MonitorControl/MonitorControl/releases) and download the latest `.dmg`, or you can install via Homebrew:
```shell
brew install --cask monitorcontrol
```

## Major features

- Control your display's brightness, volume and contrast!
- Shows native OSD for brightness and volume.
- Supports multiple protocols to adjust brightness: DDC for external displays (brightness, contrast, volume), native Apple protocol for Apple and built-in displays, Gamma table control for software dimming, shade control for AirPlay, Sidecar and Display Link devices and other virtual screens.
- Supports smooth brightness transitions.
- With smooth adjustment enabled, holding media keys or custom brightness, contrast, and volume shortcuts adjusts continuously according to elapsed time; releasing stops the adjustment. A tap changes the logical level by 0.5%, and holding changes it by 20 percentage points per second. Fine control reduces that speed and tap size to one quarter. Disabling smooth adjustment retains traditional keyboard steps. DDC monitors still quantize these values to the integer levels supported by their hardware; this cannot provide unlimited physical precision. A 30-second safeguard stops adjustment if a key-release event is lost.
- Seamlessly combined hardware and software dimming extends dimming beyond the minimum brightness available on your display.
- Synchronize brightness from built-in and Apple screens - replicate Ambient light sensor and touch bar induced changes to a non-Apple external display!
- Sync up all your displays using a single slider or keyboard shortcuts.
- Allows dimming to full black.
- Support for custom keyboard shortcuts as well as standard brightness and media keys on Apple keyboards.
- Dozens of customization options to tweak the inner workings of the app to suit your hardware and needs (don't forget to enable `Show advanced settings` in app Settings).
- Simple, unobtrusive UI to blend in to the general aesthetics of macOS.
- Completely FREE.

For additional features, more advanced brightness control with XDR/HDR brightness upscaling and support for more Mac models and displays, check out [BetterDisplay](https://github.com/waydabber/BetterDisplay#readme)!

### Screenshots (Settings)

<div align="center">
<img src=".github/pref_1.png" width="392" alt="Screenshot"/>
<img src=".github/pref_2.png" width="392" alt="Screenshot"/>
<img src=".github/pref_3.png" width="392" alt="Screenshot"/>
<img src=".github/pref_4.png" width="392" alt="Screenshot"/>
</div>

## How to install and use the app

1. [Download the app](https://github.com/MonitorControl/MonitorControl/releases)
2. Copy the MonitorControl app file from the .dmg file to your Applications folder
3. Click on the `MonitorControl` app
4. Add the app to `Accessibility` under `System Settings` » `Privacy & Security` as prompted (this is required only if you wish to use the native Apple keyboard brightness and media keys - if this is not the case, you can safely skip this step).
5. Use your keyboard or the sliders in the app menu (a brightness symbol in the macOS menubar as shown on the screenshot above) to control your displays.
6. Open `Settings…` for customization options (enable `Show advanced settings` for even more options).
7. You can set up custom keyboard shortcuts under the `Keyboard` in Settings (the app uses Apple media keys by default).
8. If you have any questions, go to [Discussions](https://github.com/MonitorControl/MonitorControl/discussions)!

### macOS compatibility

| MonitorControl version | macOS version     |
| ---------------------- | ----------------- |
| v4.0.0                 | Catalina 10.15*   |
| v3.1.1                 | Mojave 10.14      |
| v2.1.0                 | Sierra 10.12      |

_* With some limitations - full functionality available on macOS 11 Big Sur or newer._

For macOS 27 Golden Gate compatibility [v4.4.0 or newer](https://github.com/MonitorControl/MonitorControl/releases) is required!

This fork uses a compact top-right HUD on macOS 26 and newer for volume, mute, brightness, and contrast. It uses AppKit's glass effect view inside a transparent, rounded window and displays MonitorControl's actual level. This is an app-rendered HUD: Apple's Control Center OSD does not reliably reflect externally supplied monitor values. Older macOS versions retain the system OSD.

### Supported displays

- Most modern LCD displays from all major manufacturers supported implemented DDC/CI protocol via USB-C, DisplayPort, HDMI, DVI or VGA to allow for hardware backlight and volume control.
- Apple displays and built-in displays are supported using native protocols.
- LCD and LED Televisions usually do not implement DDC, these are supported using software alternatives to dim the image.
- DisplayLink, Airplay, Sidecar and other virtual screens are supported via shade (overlay) control.

Notable exceptions for hardware control compatibility:

- DDC control using the built-in HDMI port of the 2018 Intel Mac mini, the built-in HDMI port of all M1 Macs (MacBook Pro 14" and 16", Mac Mini, Mac Studio) and the built-in HDMI port of the entry level M2 Mac mini are not supported. Use USB-C instead or get [BetterDisplay](https://betterdisplay.pro) for full DDC control over HDMI with these Macs as well for free. Software-only dimming is still available for these connections.
- Some displays (notably EIZO) use MCCS over USB or an entirely custom protocol for control. These displays are supported with software dimming only.
- DisplayLink docks and dongles do not allow for DDC control on Macs, only software dimming is available for these connections.

## Contributing to the project

- If you want, you can fork the code, make improvements and submit a pull request to improve the app. Accepting a PR is solely in the hands of the maintainer - before making fundamental changes expecting it to be accepted, please consult the maintainer of the project!

## How to build

### Required

- Xcode
- [Swiftlint](https://github.com/realm/SwiftLint)
- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)
- [BartyCrouch](https://github.com/Flinesoft/BartyCrouch) (for updating localizations)

### Build steps

- Clone the project via this Terminal command:

```sh
git clone https://github.com/MonitorControl/MonitorControl.git
```

- If you want to clone one of the branches, add `--single-branch --branch [branchname]` after the `clone` option.
- You're all set! Now open the `MonitorControl.xcodeproj` with Xcode! The dependencies will automatically get downloaded once you open the project. If they don't: `File > Packages > Resolve Package Versions`

### App icon development

The app and login helper compile `MonitorControl/AppIcon.icon` with the asset catalog. This Icon Composer document supplies an explicit modern macOS icon instead of relying on the system to wrap the legacy transparent icon in a gray tile. Building it requires Xcode 26 or newer. The existing `AppIcon.appiconset` remains available for compatibility.

The modern icon reuses the original 1024-pixel artwork without changing its pixels. Its 1.25 scale removes the artwork's built-in outer padding before the system applies its icon mask. Keep the document named `AppIcon.icon`, matching `ASSETCATALOG_COMPILER_APPICON_NAME`, and include it in both targets. When changing the artwork, update its copy in `AppIcon.icon/Assets` too.

Validate the compiled `Assets.car` contains `AppIcon` entries of type `IconImageStack`, check the installed app's icon, and keep the same signing identity between local installations to preserve macOS permission grants. Icon appearance on another Mac still needs verification there.

### Publishing this fork

GitHub Actions remains disabled. Releases are prepared locally with `scripts/prepare-release.sh`, using the `Personal-Mac-Releases` notarization Keychain profile and Developer ID team `9L6898HMMN`. Sparkle's separate Ed25519 signing key is stored in the login Keychain under account `fqf555.MonitorControl`; only its public key belongs in the repository. Preserve that private key and the Developer ID identity for future updates.

Before preparing a release, increase `MARKETING_VERSION` for both targets and `CFBundleVersion` in both Info.plists. Release builds preserve the explicit build number; Debug builds retain the existing automatic increment. The script runs checks, builds arm64, verifies signing, notarizes, staples, checks Gatekeeper acceptance, and generates a signed update archive and appcast under ignored `dist/<version>-<build>/updates`.

Commit the source and create/push the matching `v<version>` tag to `origin`. Create a draft GitHub release from that tag and upload the generated ZIP, `appcast.xml`, and `SHA256SUMS` together. Publish it as the latest stable release only when all assets are ready. The stable feed URL is `https://github.com/fqf555/MonitorControl/releases/latest/download/appcast.xml`; enclosure URLs point to immutable, version-specific release assets. Do not reuse tags or overwrite published update archives. Download and verify the public artifacts and exercise Check for updates after publishing. Intel Macs must not be offered these arm64-only releases.

### Third party dependencies

- [MediaKeyTap](https://github.com/MonitorControl/MediaKeyTap)
- [Settings](https://github.com/sindresorhus/Settings)
- [SimplyCoreAudio](https://github.com/rnine/SimplyCoreAudio)
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
- [Sparkle](https://github.com/sparkle-project/Sparkle)

## Credits

- [@waydabber](https://github.com/waydabber), maintainer, developer of [BetterDisplay](https://github.com/waydabber/BetterDisplay#readme).
- [@the0neyouseek](https://github.com/the0neyouseek) - honorary maintainer
- [@JoniVR](https://github.com/JoniVR) - honorary maintainer
- [@alin23](https://github.com/alin23) - spearheaded M1 DDC support, developer of [Lunar](https://lunar.fyi)
- [@mathew-kurian](https://github.com/mathew-kurian/) (original developer)
- [@Tyilo](https://github.com/Tyilo/) (fork)
- [@Bensge](https://github.com/Bensge/) - (used some code from his project [NativeDisplayBrightness](https://github.com/Bensge/NativeDisplayBrightness))
- [@nhurden](https://github.com/nhurden/) (for the original MediaKeyTap)
- [@kfix](https://github.com/kfix/ddcctl) (for ddcctl)
- [@reitermarkus](https://github.com/reitermarkus) (for Intel DDC support)
- [javierocasio](https://www.deviantart.com/javierocasio) (app icon background)
