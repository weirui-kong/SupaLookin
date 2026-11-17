# SupaLookin Helper (splkhidd)

On a jailbroken device below iOS 27, this helper lets Supa Lookin's Live Control and its MCP tools (`tap_at`, `press_button`) operate the whole device. Touches and buttons reach the software keyboard, system alerts, the home screen and other apps, not just the inspected app. Devices without it can only be watched. See `spec/20261118-protocol-v2-m12-jailbreak-input.md`.

It supports rootless jailbreaks such as Dopamine (iOS 15 or later).

## Build

```sh
JailbreakHelper/build.sh
```

The package is written to `JailbreakHelper/build/org.supacode.app.lookin.splkhid.deb`. A copy also goes to `SupaLookin/Live/Resources/`, which the app bundles; commit it with the helper's source. The build needs Xcode's iPhoneOS SDK; it doesn't need Theos.

## Install

In Live Control, the "Need help?" link at the bottom left opens "Operating Devices". There, "Copy Package to Device" puts the package, which is bundled with the app, into `/var/mobile/Media/SupaLookin/`, and the sheet gives the install command with a copy button. "Check This Device" then tells whether the device can be operated.

By hand, copy the package to the device and install it as root, for example over SSH:

```sh
sudo dpkg -i org.supacode.app.lookin.splkhid.deb
```

Sileo or Filza can install it too. To remove it, use `sudo dpkg -r org.supacode.app.lookin.splkhid`.

## What it does on the device

- **Launching**: launchd listens on `127.0.0.1:47290`. It starts the helper, as `mobile`, only when Supa Lookin connects over USB. The helper exits 30 s after the connection ends.
- **Pairing check**: a connection must carry a one-time token. Supa Lookin writes the token into `/var/mobile/Media/SupaLookin` over AFC, which only a paired Mac can reach and apps on the device can't read.
- **Lock check**: nothing is accepted while the device is locked. When it locks during a session, input stops until it's unlocked.
