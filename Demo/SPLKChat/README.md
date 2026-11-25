# SPLK Chat

A small chat app for trying Supa Lookin against something realistic: inspecting, Live Control, and agent takeover over MCP, on simulators and on devices.

It embeds SPLKServer as a dynamic framework, through the `SPLKServerDynamic` product of the repository root's `Package.swift`. Nothing in the app imports it: SPLKServer starts itself once the app finishes launching, and listens on 127.0.0.1:47264–47269 on a simulator, or on 47275–47279 over USB on a device.

SPLKServer only compiles in the Debug configuration, so build Debug. A Release build still embeds the framework, but nothing in it listens.

## What's in it

- **Chats**: a conversation list with unread badges and swipe actions. The ⊕ button opens an action sheet that can also simulate an incoming message. A conversation has message bubbles and a text field with a Send button. Sending appends a bubble, and a reply arrives about a second later.
- **Contacts**: an alphabetical list with a search bar and section index. A contact opens a detail page with Send Message and Voice Call buttons.
- **Discover**:
  - Moments: a 200-row feed with pull to refresh.
  - System alerts: Photos, Notifications and Location permission requests.
  - App alerts: a `UIAlertController` alert, one with a text field, and an action sheet.
  - Inspector cases: Masks, with a `maskView` with subviews, a `CAShapeLayer` mask, a gradient fade, a mask with its own mask, and a mask a switch adds and removes. Launch with `-SPLKChatScreen masks` to open it directly.
- **Me**: a profile header, switches (Dark Mode switches the window's appearance), a slider, and destructive confirmation alerts.

Key controls have accessibility identifiers, such as `conversation.input`, `conversation.send` and `contacts.search`.

## Simulator

Open `SPLKChat.xcodeproj` in Xcode, pick a simulator and run. Or, from this folder:

```bash
xcodebuild -project SPLKChat.xcodeproj -scheme SPLKChat -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build
```

```bash
xcrun simctl install booted DerivedData/Build/Products/Debug-iphonesimulator/SPLKChat.app
```

```bash
xcrun simctl launch booted icu.retrouvailles.splkchat
```

Check that SPLKServer is listening:

```bash
lsof -nP -iTCP:47264-47269 -sTCP:LISTEN
```

Supa Lookin then lists SPLK Chat among its apps.

System permission alerts are drawn by SpringBoard, not by the app. Live Control reaches them on a simulator through host-side input.

## Device

The project signs automatically with team `4L8444Q855`, the same team as the macOS app. To use another team, choose it under the SPLKChat target's Signing & Capabilities in Xcode, or pass `DEVELOPMENT_TEAM=<TEAM_ID>` to `xcodebuild`. If that team can't register `icu.retrouvailles.splkchat`, change the bundle identifier too.

Then pick the device and run. Or, on iOS 17 or later, from this folder, replacing `<DEVICE>` with the device's identifier (`xcrun devicectl list devices`). `devicectl` doesn't reach iOS 16 devices; run those from Xcode.

```bash
xcodebuild -project SPLKChat.xcodeproj -scheme SPLKChat -destination 'generic/platform=iOS' -derivedDataPath DerivedData -allowProvisioningUpdates build
```

```bash
xcrun devicectl device install app --device <DEVICE> DerivedData/Build/Products/Debug-iphoneos/SPLKChat.app
```

```bash
xcrun devicectl device process launch --device <DEVICE> icu.retrouvailles.splkchat
```

Keep the device connected over USB. Supa Lookin reaches SPLKServer through usbmuxd on ports 47275–47279.

## Jailbroken device with TrollStore

TrollStore installs the app without a development team or provisioning profile, and the install doesn't expire. Build a Debug IPA, signed ad hoc:

```bash
./build-ipa.sh
```

It writes `DerivedData/SPLKChat.ipa`. Pass another path as the first argument to write it elsewhere.

Get the IPA onto the device, for example with AirDrop, and open it in TrollStore. Or, over SSH as `mobile`:

```bash
scp DerivedData/SPLKChat.ipa mobile@<DEVICE_HOST>:/var/mobile/Documents/
```

```bash
ssh -t mobile@<DEVICE_HOST> 'sudo "$(ls -d /var/containers/Bundle/Application/*/TrollStore.app)/trollstorehelper" install /var/mobile/Documents/SPLKChat.ipa'
```

Apps installed this way can't be launched or debugged from Xcode. Supa Lookin still reaches them over USB.

The app itself needs nothing extra on a jailbroken device. Reaching the software keyboard and system alerts there depends on the on-device helper in `JailbreakHelper/`, not on this app.
