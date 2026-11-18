# Protocol v2 M12: host-side input on jailbroken devices

## Summary

M12 lets Supa Lookin fully operate a jailbroken USB device below iOS 27, as `20261118-control-roadmap.md` plans:
- **The helper**: a small daemon, `splkhidd`, installed with the jailbreak's package manager, dispatches touches and buttons into the device's HID event system.
- **Reach**: they reach everything a finger does, including the software keyboard, system alerts, the home screen and other apps.
- **Delivery**: Supa Lookin sends them over usbmux.

**Who it serves**: devices without the helper stay watch-only. It serves rootless jailbreaks, with Dopamine as the target.

## Background

**The spike**, on an iPhone 14 (iOS 16.1, Dopamine, rootless). A command-line tool built on the Mac, signed with the entitlements below and run from `/var/jb` as `mobile`:
- tapped the home screen's Search button, which opened Spotlight;
- tapped a key of the software keyboard, which typed it;
- pressed Home, which closed Spotlight;
- pressed Lock, which locked the device, after which the helper refused to greet.

**What it took**, from backboardd's log:
- **The client type**: `IOHIDEventSystemClientCreate` makes a rate-controlled client, whose dispatched events go nowhere. `IOHIDEventSystemClientCreateWithType` with the administrative type (0) works.
- **The sender ID**: backboardd drops a digitizer event whose sender isn't a digitizer ("ignoring digitizer event from non-digitizer sender"). Touches must carry the registry ID of the hardware touchscreen's HID service (usage page 0x0D, usage 0x04). Buttons must carry that of Apple's vendor-page button service (page 0xFF00, usage 0x04), where the side button reports: SpringBoard ignores a Lock press from the consumer-control service (page 0x0C, usage 0x01), though Home works from either. The IDs differ per device, so the helper looks them up.
- **Trust**: Dopamine runs ad-hoc signed binaries from under `/var/jb` without other steps. A binary elsewhere is killed.

## The helper

**Repository layout**: `JailbreakHelper/` holds `splkhidd.m` (Objective-C), its entitlements, its launchd plist, the package's `control` file, and `build.sh`. It isn't part of the Swift package.

**Build**: `build.sh` compiles for arm64 with the iPhoneOS SDK (iOS 15 or later), signs ad hoc with the entitlements, and assembles a rootless package.

| Path | File |
|---|---|
| `/var/jb/usr/libexec/splkhidd` | the daemon |
| `/var/jb/Library/LaunchDaemons/org.supacode.app.lookin.splkhid.plist` | launchd job, run as `mobile`, started on demand by its socket |

The package's `postinst` loads the job, and `prerm` unloads it.

**Entitlements**:
- `com.apple.private.hid.client.event-dispatch`;
- `com.apple.private.hid.client.admin`;
- `com.apple.private.hid.client.service-protected`;
- `platform-application`.

**Behavior**:
- **Listening**: launchd holds the socket, `127.0.0.1:47290`, and starts the helper when a client connects; the helper takes it with `launch_activate_socket`. The helper serves one client at a time and exits 30 s after its last client leaves, so nothing runs while Supa Lookin isn't using the device. Started outside launchd, for development, it binds the port itself.
- **On start**: it creates an administrative HID client and finds the two senders among the client's services.
  - The same usage can be served by virtual services too: the iPhone 14 has three touchscreens, two of them virtual (accessibility and `druid`), and all three claim `Built-In`.
  - Hardware services carry IORegistry entry IDs, below 2^33, while virtual ones carry larger, pointer-like IDs. So the helper takes the hardware service with the lowest registry ID for each usage.
  - It looks again when a client connects, in case services changed.
- **Touches** become one digitizer event per frame:
  - a hand event (transducer type 3, display-integrated) with one finger child per contact;
  - each child carries its identity, its point, and touch and range flags;
  - the event mask carries touch, range and position;
  - the sender is the touchscreen.
- **Buttons** become keyboard events with the button's usage page and usage, down and then up after the requested hold, from the vendor-page button service, or consumer control on a device without it.

## Security

The helper can touch anything on the device, so it serves only Supa Lookin on a paired Mac, and only while the device is unlocked.

- **On demand**: launchd starts the helper only when a client connects, as above.
- **A token from the paired Mac**: any app on the device can connect to a loopback port, so a connection must first prove it comes from a Mac the device is paired with.
  - Before connecting, Supa Lookin writes a fresh token (32 random bytes, hexadecimal) to `/var/mobile/Media/SupaLookin/splkhid-token`. It uses AFC, the media-folder service that only paired hosts can start, through MobileDevice.framework (`AMDeviceSecureStartService` for `com.apple.afc`).
  - Sandboxed apps can't read that folder.
  - The helper reads the token file when the greeting arrives, compares it in constant time, and deletes it, so each token works once. A file older than 60 s is refused.
- **Unlocked only**: the helper asks SpringBoard whether the screen is locked, through `SBSGetScreenLockStatus` (SpringBoardServices, with the `com.apple.springboard.getScreenLockStatus` entitlement). Where that's missing, it uses MobileKeyBag's `MKBGetDeviceLockState`, where 0 is unlocked and 3 means no passcode.
  - SpringBoard's `com.apple.springboard.lockstate` isn't the answer: it's also nonzero while Notification Center is pulled down over an unlocked device. That notification, `com.apple.springboard.hasBlankedScreen` and `com.apple.mobile.keybagd.lock_status` only tell the helper when to ask again. The keybag one comes first when Face ID unlocks the device while its lock screen still shows.
  - A greeting while locked is refused with `locked`.
  - When the device locks during a session, the helper lifts any finger still down, ignores touches and buttons, and tells the client. It tells the client again on unlock.

## The wire protocol

The protocol is ASCII lines ending in `\n`, so the helper needs no protobuf. Numbers are decimal, except usages, which are hexadecimal.

| From | Line | Meaning |
|---|---|---|
| client | `HELLO 1 <token>` | First line, with the token just written over AFC. |
| helper | `SPLKHID 1 OK` | Ready: the token matched, the device is unlocked and both senders were found. |
| helper | `SPLKHID 1 ERROR <reason>` | Not ready: `token`, `locked`, `no-touchscreen` or `no-buttons`. The connection closes. |
| helper | `STATE locked`, `STATE unlocked` | The device locked or unlocked during the session. While locked, touches and buttons are ignored. |
| client | `T <id>:<x>:<y>:<down> …` | One touch frame. One field per finger still down or lifting in this frame. `id` is 0–9; `x` and `y` are 0–1, from the top left of the display's native portrait frame; `down` is 1 while touching and 0 on the frame where it lifts. |
| client | `B <page> <usage> <holdMs>` | A button press, for example `B c 40 80` for Home. |

Apart from `STATE` lines, the helper answers nothing after the greeting, so frames never wait on a round trip. A line it can't parse closes the connection.

## Mac

### SPLKJailbreakHIDInput

`SPLKJailbreakHIDInput` adopts the host-side input interface of M9, `SPLKHostInput`, alongside `SPLKSimulatorHIDInput`. `SPLKDeviceSession` creates it for USB devices.

- **Connecting**: `connect()`:
  1. writes a fresh token over AFC;
  2. opens usbmux port 47290 on the session's device;
  3. sends `HELLO 1 <token>`;
  4. waits up to 2 s for `SPLKHID 1 OK`.

  Any other outcome leaves the device watch-only, with the error's reason.
- **Lock state**: `STATE` lines update the session's input availability, so Live Control shows the device as locked and stops sending input until it unlocks.
- **Touches**:
  - `SPLKTouchFrameEncoder` turns InjectInput touches into frames.
  - It keeps each live `touch_id`'s identity and point. Every frame carries every live finger, plus each finger lifting in it.
  - Points go to the native portrait frame with `SPLKDigitizerTranslator.nativePoint`.
- **Buttons**: Home is `B c 40 80`. Lock is `B c 30 100`: a short press, since holding the side button calls up Siri.
- **Text, keys and shakes** stay device-side, as in M9.
- **Disconnects**: a broken connection is reopened on the next input. If that fails, the device turns watch-only until the session reconnects.

`SPLKDeviceSession` tracks the session's usbmux device ID, given by `SPLKConnectionManager`, so the helper is reached on the same device.

### Watch-only devices

`SPLKDeviceSession.inputAvailability` answers for a USB device:
- `host`: the helper answered;
- `watchOnly(reason)`: it didn't.

**What changes for a watch-only device**:
- In Live Control, the video takes no input. The pointer shows as not-allowed over it, as in Takeover.
- Shake, Home and Lock are disabled.
- MCP's `tap_at` and `press_button` fail, saying the device can only be watched.
- MCP's semantic actions keep working.

**The note**: a line of small secondary text at the bottom left of the video area says why.

| Device | Note |
|---|---|
| iOS 27 or later | Operating devices on iOS 27 or later is coming soon. This device can only be watched. |
| below iOS 27 | Operating this device needs a jailbreak and the SupaLookin helper. This device can only be watched. |
| the helper refused the greeting with `locked`, or reported `STATE locked` | Unlock the device to operate it. |

Simulators are unchanged.

### The help panel

In Live Control, a "Need help?" link (13 pt) sits at the bottom left of the video area, before the note. It opens a sheet titled "Operating Devices" with three parts.

**1. Support.** A table of what each target allows. A target and its operation read green where it can be fully operated, orange where only partly, and red where not at all. Watching reads green throughout.

| Target | Watch | Operate |
|---|---|---|
| Simulator, Xcode 27 or later | yes | everything |
| Simulator, Xcode 26 | yes | the app only; everything is planned |
| Device, iOS 27 or later | yes | coming soon |
| Device below iOS 27, jailbroken, with the SupaLookin Helper | yes | everything, while unlocked |
| Other devices | yes | no |

**2. Installing the SupaLookin Helper**, for jailbroken devices below iOS 27 on a rootless jailbreak:
1. **Copy the package.** "Copy Package to Device" writes the helper package, built into Supa Lookin, to `/var/mobile/Media/SupaLookin/org.supacode.app.lookin.splkhid.deb` over AFC. The button is enabled for USB devices only, and the sheet shows the result.
2. **Install it as root**, in a terminal on the device or over SSH. The command has a copy button:

   `sudo dpkg -i /var/mobile/Media/SupaLookin/org.supacode.app.lookin.splkhid.deb`

   Alternatively, open the file in Filza and install it there.
3. **Removing it** takes this command, also with a copy button:

   `sudo dpkg -r org.supacode.app.lookin.splkhid`

**3. Checking this device.** "Check This Device" runs `refreshInputAvailability()` and shows what the session found:

| Result | Shown |
|---|---|
| host-side input on a simulator | Full control, through the simulator. |
| host-side input on a device | Full control, through the SupaLookin Helper. |
| input inside the app only | Only the app's own screens respond. Xcode 27 or later gives full control. |
| locked | The helper is installed. Unlock the device to operate it. |
| iOS 27 or later, without the helper | Operating devices on iOS 27 or later is coming soon. |
| below iOS 27, the helper not reached | The SupaLookin Helper wasn't found. Install it on a jailbroken device. |
| below iOS 27, the helper refused for another reason | The helper's reason, such as `token` or `no-touchscreen`. |

The device's name and iOS version head the result.

**The bundled package**: `JailbreakHelper/build.sh` also copies its package to `SupaLookin/Live/Resources/org.supacode.app.lookin.splkhid.deb`. The repository keeps that copy, so building the macOS app doesn't need the iPhoneOS SDK.

### The first screen capture

The first time a Mac process captures a device's screen, the device re-attaches over USB with a new usbmux device ID. That ends the app's session, so the first Live Control in each launch dropped the app at once. Captures after that, in the same process, keep the session. Allowing and listing screen devices alone doesn't cause it.

**What the window does about it**:
- **Resuming**: when the app drops while the window is in Live Control, and the app reconnects by itself within 30 s, Live Control starts again on the new session. Picking an app by hand doesn't resume.
- **Saying it's expected**: when the drop comes within 15 s of Live Control starting, a toast at the window's bottom right says so. It reads "Switching the device to screen capture…", with "The device reconnects the first time its screen is captured. Live Control comes back by itself." It goes away when Live Control resumes, when another app is picked, or after 30 s.

**`SPLKToast`** is a general component for news that needs no answer, so it can stand in for some alerts later:
- a message (14 pt), an optional detail line (12 pt), and a style (info, success, warning, error) that picks the icon and its tint;
- shown at the bottom right of a window, one per window, a new one replacing the old;
- goes away after a duration (4 s by default) or a click; a nil duration keeps it until `dismiss()`;
- announced to VoiceOver.

## Verification

- **`SupaLookinTests`**:
  - `SPLKTouchFrameEncoder`: one and several fingers, identities kept, lifting fingers in their last frame, cancel, lines formatted as above;
  - the button lines;
  - the availability rules and the note for each case.
- **The helper, on the iPhone 14**, started by hand as `mobile`:
  - a greeting without a valid token is refused, and a token works only once;
  - a greeting while locked is refused, and locking during a session sends `STATE locked` and stops input;
  - pulling Notification Center down over the unlocked device sends nothing, and taps keep working;
  - it exits 30 s after its client leaves.
- **The helper, on the iPhone 14**, through the package installed by hand:
  - it greets with `OK`;
  - a frame tapping Search opens Spotlight;
  - a frame tapping a software keyboard key types it;
  - `B c 40 80` goes home.
- **By hand, in Live Control on the iPhone 14**:
  - clicking the demo's button;
  - typing by clicking the software keyboard;
  - answering an alert;
  - Home, then opening the demo from its icon;
  - a two-finger pinch.
- **By hand**, the help panel:
  - the table and both commands copy as shown;
  - "Copy Package to Device" puts the package on the iPhone 14;
  - "Check This Device" reports full control on the iPhone 14 and on the iPhone Duo simulator, and coming soon on the iPhone 12 mini.
- **`SPLKJailbreakLiveTests`** on the iPhone 14, in a fresh process: if the first capture drops the app, the app comes back, and a capture on the new session keeps it.
- **By hand**, the first Live Control after launching Supa Lookin on the iPhone 14: the toast shows, then Live Control comes back by itself.
- **`SupaLookinTests`**: a toast shows in its window, a second replaces it, and `dismiss()` removes it.
- **By hand**, on the iPhone 17 Pro Max (iOS 26.1, not jailbroken) and the iPhone 12 mini (iOS 27.2): watch-only, with the right note.

## Out of scope

- Rootful jailbreaks and palera1n's rootful mode.
- The software keyboard's hardware-keyboard mode.
- Distributing the package through a repository; it's built from this repository and installed by hand.

## Update: toasts at the bottom left (see `20261119-toast-notices.md`)

Toasts, the reconnect toast included, now show at the window's bottom left.
