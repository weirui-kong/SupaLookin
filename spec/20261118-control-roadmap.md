# Control roadmap

## Summary

This spec sets how far Supa Lookin lets a person or an agent operate a simulator or a device, and the milestones that get there. It extends the Milestones of `20261109-protocol-v2.md`.

"Operating" means input the window or an agent sends as touches and buttons:
- clicks and gestures on the video in Live Control;
- MCP's `tap_at` and `press_button`;
- the Device menu's Home and Lock.

**Full operation** reaches the whole simulator or device, not just the inspected app:
- the software keyboard;
- system alerts;
- the home screen;
- other apps.

## Scope

| Target | Watch | Operate | Milestone |
|---|---|---|---|
| Simulator, Xcode 27 or later | yes | full, through `dtuhidd` in the simulator | M9 (done) |
| Simulator, Xcode 26 | yes | full, through SimulatorKit's Indigo HID | M11 |
| Device, iOS 27 or later | yes | full, through CoreDevice HID | M10 |
| Device below iOS 27, jailbroken | yes | full, through a helper installed with the jailbreak | M12 |
| Device below iOS 27, not jailbroken | yes | none | — |

- **Watching** is Live Control's and Takeover's video:
  - for simulators, the CoreSimulator framebuffer;
  - for devices, CoreMediaIO.

  Both work for every iOS version a target runs.
- **Without full operation**, a device is watch-only. The video area says why in a line of small text at its bottom left, and Live Control takes no input there.
- **Not affected by this table**:
  - **Inspect mode**: the hierarchy, attributes, modifications and method invocation.
  - **MCP's semantic actions** (`tap`, `long_press`, `set_text`, `scroll`, `scroll_to_visible`, `swipe`, `go_back`): they act on an item by its oid through the app's own accessibility and control actions (M6), and work on every target.
- **Requirements for full operation**:
  - Devices need Developer Mode and pairing, and the Mac needs Xcode 27. Xcode mounts the Developer Disk Image when a device connects.
  - Simulators need only the Xcode in the table.

## Milestones

| Milestone | Scope | State |
|---|---|---|
| M1–M6 | Protocol v2: core, server, Mac, control and events, device-side input, agents | done |
| M7 | Mac-side video for simulators and devices | done |
| M8 | The modes in the window | done |
| M9 | Full operation of simulators on Xcode 27 | done |
| M10 | Full operation of devices on iOS 27 or later; the watch-only note | next |
| M11 | Full operation of simulators on Xcode 26, through Indigo HID as facebook/idb sends it | planned |
| M12 | Full operation of jailbroken devices below iOS 27 | planned |

### M11: simulators on Xcode 26

- **Mechanism**: CoreSimulator below 1155.4 has no `dtuhidd` and still takes Indigo messages through SimulatorKit's `SimDeviceLegacyHIDClient`. idb builds the messages with `IndigoHIDMessageForMouseNSEvent` and SimulatorKit's other `IndigoHIDMessageFor…` functions.
- **Selection**: `SPLKSimulatorHIDInput` picks Indigo by the CoreSimulator version, as idb does.
- **Testing**: verification needs a Mac with Xcode 26.

### M12: jailbroken devices

- **The helper**: a rootless daemon, built with Theos and installed from the jailbreak's package manager, injects HID events system-wide through `IOHIDEventSystemClient`.
- **Connection**: Supa Lookin finds it over usbmux on its own port range and sends it the same touch and button events as M10.
- **Jailbreaks**: it targets the current rootless jailbreaks, Dopamine and palera1n. Their coverage limits who can use it.
- **Testing**: verification needs a jailbroken device.

### Later

- Element-targeted taps on devices, from the element frames of `remoteAXService` (iOS 27).
- `hierarchy.diff`, in-app video and Wi-Fi discovery, from `20261109-protocol-v2.md`.

## Update: M12 before M10 (see `20261118-protocol-v2-m12-jailbreak-input.md`)

- **Order**: M12, jailbroken devices, comes next. A jailbroken iPhone 14 (iOS 16.1, Dopamine) is available to verify it.
- **M10 is on hold.** Devices on iOS 27 or later stay watch-only, and the note says operating them is coming soon. M10's transport is unsettled:
  - Supa Lookin's own RSD connection is evicted by `remoted` within seconds, and the device closes its services once that connection goes;
  - CoreDevice's service socket can only be reached through private Swift API.
- **Note wording** for watch-only devices is set in M12's spec.
