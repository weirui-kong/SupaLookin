# Protocol v2 M10: host-side input on devices

## Summary

M10 brings M9's host-side input to USB devices running iOS 27 or later. The Mac sends touches and buttons into the device's own HID system, so they reach what device-side input (M5) can't:
- the software keyboard;
- system alerts;
- the home screen;
- other apps.

**The mechanism**:
- Xcode 27's Developer Disk Image puts a HID daemon, `dtuhidd`, on the device.
- It serves CoreDevice HID services over the device's CoreDevice tunnel.
- Device Hub, Xcode 27's device window, drives devices this way.

**Watch-only devices**: devices below iOS 27 are watch-only in Live Control, as `20261118-control-roadmap.md` sets out. The window says so in a small note.

## Background

**The spike**, on an iPhone 12 mini (iOS 27.2, USB), driven from this Mac with pymobiledevice3 over macOS's own tunnel:
- A tap on Settings' search field opened the search and brought up the software keyboard.
- A tap on the keyboard's one-time tip, then on its "w" key, typed "w"; the Pinyin candidate bar appeared.
- While Supa Lookin captured the screen through CoreMediaIO (M7), HID taps went through and the capture kept running.

**iOS 26.1** (an iPhone 17 Pro Max): Device Hub itself can't show the screen. Reports from other projects agree that iOS 26 and earlier refuse remote control.

**Where the protocol comes from**: it follows pymobiledevice3 (`remote/core_device/hid_service.py`, `display_service.py`, `remote/native_tunnel.py`) and jkcoxson/idevice (`hid.rs`). No Apple documentation exists.

**Requirements on the device**:
- iOS 27 or later;
- Developer Mode on;
- the Developer Disk Image mounted, which Xcode does when the device connects;
- paired with this Mac.

## Transport

`SPLKDeviceServiceConnector` gives a RemoteXPC connection to a named service on a device, found by UDID. Two ways to get one were found:

| | A. CoreDevice's service socket | B. Supa Lookin's own RSD connection |
|---|---|---|
| How | CoreDevice's `com.apple.coredevice.action.createservicesocket` action, run by `CoreDeviceService` (Xcode's device daemon). CoreDevice's `remoteXPCConnection(toServiceNamed:connectionMode:handlingEventsOn:)` returns the connection. | `remotepairingd` (RemotePairing.framework, base macOS) is asked for a tunnel assertion and the device's tunnel address. Supa Lookin then completes the RemoteServiceDiscovery (RSD) handshake on that tunnel itself and connects to the service's port. |
| Cost | CoreDevice is a Swift framework with no interface file. Calling it means reverse-engineering its entry points. | The device keeps one RSD connection per tunnel, so Supa Lookin's evicts `remoted`'s, and Xcode briefly loses the device. Finding the RSD port means reading `remoted`'s socket in the TCP table. M10 would also need its own RemoteXPC (HTTP/2 and XPC wire format). |
| Entitlements | None: Device Hub and devicectl carry none | None |

**Step 1 decides.** M10 starts by calling A from an unentitled build of Supa Lookin. If it works, M10 uses A only. If it can't be reached, M10 uses B, and keeps B's RSD connection only for the handshake, so `remoted` gets its connection back at once. An update to this spec records the outcome.

## Services

### The media stream gate

`dtuhidd` publishes the host's HID surfaces as unauthenticated until a CoreDevice media stream runs. Until then, backboardd drops every touch.

**Opening the stream**:
1. Bind a UDP socket on the host's tunnel address.
2. Send `com.apple.coredevice.action.mediastreamstart` to `com.apple.coredevice.displayservice`, with an offer naming that socket as the receiver and the main display.
3. Wait 0.5 s before the first touch.

**While it runs**: the device sends RTP to the socket, and Supa Lookin discards it. The video still comes from CoreMediaIO (M7), since the spike showed the two run together.

**Ending it**: `com.apple.coredevice.action.mediastreamstop` ends the stream when input ends.

### Touch

**Service**: `com.apple.coredevice.hid.universalhidservice`.

**Each report** is one XPC message:

| Key | Value |
|---|---|
| `featureIdentifier` | `com.apple.coredevice.feature.remote.universalhidservice` |
| `messageType` | `Request` |
| `payload` | `{send: {_0: <report data>, _1: <uint64 service ID>}}` |

The service ID is 257, the main touchscreen.

**The touchscreen report**, 58 bytes:

| Bytes | Meaning |
|---|---|
| 0 | report ID `0x09` |
| 1 | number of contacts in this report |
| 2 | maximum contacts, `5` |
| 3–27 | five contact slots of 5 bytes: state, X (UInt16 LE), Y (UInt16 LE) |
| 28–39 | zero |
| 40–43 | `02 00 00 00` |
| 44–49 | host time, Mach absolute, 6 bytes LE |
| 50–57 | zero |

- **Coordinates** run 0–65535 across the display's native portrait frame, from the top left.
- **Contact state**:
  - `0xC0 | identity` while a finger touches;
  - the bare identity once, when it lifts.
- **Identity**: each finger keeps the same one (0–4) from touch-down to lift.
- **Every report** carries every finger still down.
- There's no separate begin or end message:
  - a tap is one contact report and one release;
  - a drag is a stream of contact reports, then a release.

### Buttons

**Service**: `com.apple.coredevice.hid.indigo`.

**The message**:

| Key | Value |
|---|---|
| `featureIdentifier` | `com.apple.coredevice.feature.remote.hid.button` |
| `messageType` | `IndigoButtonEvent` |
| `payload` | `{usagePage, usageCode, state}` (uint64): down 1, up 2 |

| Button | Usage | Held |
|---|---|---|
| Home | 0x0C / 0x40 | 80 ms |
| Lock | 0x0C / 0x30 | 0.5 s; iOS 27 ignores shorter presses |

Text, keys and shakes stay device-side, as in M9.

## Mac

### SPLKDeviceHIDInput

`SPLKDeviceHIDInput` matches `SPLKSimulatorHIDInput`'s interface: `connect()`, `send(_:orientation:)` and `press(_:)`. `SPLKDeviceSession` creates it for a USB device whose `AppSummary.os_main_version` is 27 or later.

- **Opening**: `connect()` opens the touch and button connections and the media stream. Like M9's barrier, a failure leaves the session on device-side input.
- **Touches**:
  - `SPLKTouchReportEncoder` turns InjectInput touches into touchscreen reports.
  - It assigns each live `touch_id` the lowest free identity, and every report carries all live fingers.
  - Points are turned to the native portrait frame with `SPLKDigitizerTranslator.nativePoint`.
- **Closing**: the connections and the stream close when Live Control ends. For MCP, they close 30 s after the agent's last input.
- **Host-side input** in `SPLKDeviceSession` becomes a protocol, `SPLKHostInput`, adopted by both the simulator and the device input. `deliverInput` and `press` route through it.

### Watch-only devices

A USB device without host-side input is watch-only. That covers:
- devices below iOS 27;
- devices on iOS 27 or later that can't open host-side input, for example without Developer Mode.

**What changes for them**:
- In Live Control, the video takes no input, and the pointer shows as not-allowed over it, as in Takeover.
- Shake, Home and Lock are disabled.

**The note**: in Live Control and Takeover, a line of small secondary text sits at the bottom left of the video area:

> Operating this device needs iOS 27 or later, or a jailbroken device. It can only be watched here.

When host-side input failed on iOS 27 or later, the note gives the error's reason instead.

### Menus and MCP

- The Device menu's Home and Lock work for devices with host-side input, as for simulators.
- MCP's `tap_at` and `press_button` do too. `tap_at` reports `device` as its `input` when it used this path.
- On a watch-only device, `tap_at` and `press_button` fail, saying the device can only be watched. MCP's semantic actions (`tap`, `set_text` and the rest) act through the app itself and keep working.

## Verification

- **`SupaLookinTests`**:
  - `SPLKTouchReportEncoder`:
    - byte layout;
    - one and several fingers;
    - identities kept across moves;
    - releases;
    - the identity of a lifted finger reused.
  - The button messages.
  - The backend choice by device kind and iOS version.
- **`SPLKDeviceVideoLiveTests`**, extended. It runs against a device given by `TEST_RUNNER_SPLK_DEVICE_SERIAL`, on iOS 27 or later, with the e2e demo installed:
  - host-side input connects;
  - a tap on the demo's button taps it;
  - a tap on a software keyboard key types it;
  - Home goes to the home screen while the capture keeps running.
- **By hand**, in Live Control on the iPhone 12 mini:
  - typing on the keyboard by clicking its keys;
  - answering a permission alert;
  - Home, and opening the demo again from its icon.
- **By hand**, on the iPhone 17 Pro Max (iOS 26.1): Live Control shows the note and takes no clicks, `tap_at` fails, and MCP's `tap` on an item still works.

## Out of scope

- Jailbroken devices below iOS 27 (M12 in `20261118-control-roadmap.md`).
- The virtual HID keyboard, which would hide the software keyboard.
- Element frames from `remoteAXService` for element-targeted taps.
- Wireless devices.
- Using the CoreDevice media stream as the video source in place of CoreMediaIO.
