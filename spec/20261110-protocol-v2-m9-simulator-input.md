# Protocol v2 M9: host-side simulator input

## Summary

M9 builds the host-side input backend of `20261109-protocol-v2.md` for simulators. The Mac sends touches and buttons into the simulator itself, below every app, so they reach what device-side input (M5) can't:
- the software keyboard, which iOS 17 and later draw in a separate process;
- system alerts;
- the home screen;
- other apps.

Live Control and the MCP tools `tap_at` and the new `press_button` use it on simulators. USB devices keep device-side input.

## Background

**Why the earlier attempt failed.** The M7 research sent Indigo HID messages through SimulatorKit's `SimDeviceLegacyHIDClient`. The client accepted them and nothing happened.

**What changed in Xcode 27.**
- CoreSimulator 1155.4 and later (Xcode 27) run a HID daemon, `dtuhidd`, inside each simulator.
- Once anything has connected to `dtuhidd`, the simulator drops Indigo input for the rest of the boot. Device Hub, for one, connects to it.
- This Mac has CoreSimulator 1174.21, and `com.apple.coredevice.dtuhidd` runs in the booted simulator.

**Where the protocol comes from.** It follows facebook/idb's `FBSimulatorControl/HID` sources (MIT), which other tools have since ported. No Apple documentation exists.

**Checked on the iPhone Duo simulator** (iOS 27, CoreSimulator 1174.21), from a prototype:
- a tap on a table row selected it;
- a tap on the software keyboard's "m" key typed "m";
- a keyboard HID event typed "a";
- a Home button press went to the home screen.

## Protocol

**Connecting**
1. Look up the service: `-[SimDevice lookup:error:]` with `com.apple.coredevice.feature.remote.hid.digitizer` returns a mach port. The lookup succeeds even when the daemon isn't running.
2. Build the connection, with the libxpc functions found through `dlsym`:
   - `xpc_endpoint_create_mach_port_4sim(port, 0, 0)` makes an endpoint;
   - `xpc_connection_create_from_endpoint` makes the connection;
   - `xpc_connection_enable_sim2host_4sim` must be called before `xpc_connection_resume`, or the daemon never sees a payload.
3. **The liveness barrier** is the only proof the daemon is there:
   - it's a keyboard event with usage 0 and state up, sent with `isBarrier` true and with a reply;
   - any reply that isn't an error counts;
   - the timeout is 4 s;
   - a failed barrier is retried up to 5 times, 4 s apart, since launchd throttles the daemon's respawn.

**Messages** are one-way XPC dictionaries:

| Key | Value |
|---|---|
| `messageType` | string |
| `isBarrier` | bool |
| `featureIdentifier` | string: the service name |
| `payload` | dictionary, by type below |

| `messageType` | Payload |
|---|---|
| `IndigoDigitizerEvent` | `pointOne` {`x`, `y`: double, 0–1 from the top left}; `pointTwo` (same shape, only for two fingers); `eventType` uint64: start 0, position 1, end 2; `edge` uint64 0; `target` uint64 0 |
| `IndigoButtonEvent` | `usagePage`, `usageCode`, `state` (uint64): down 1, up 2 |
| `IndigoKeyboardButtonEvent` | `usageCode` (USB HID keyboard usage), `state`: down 1, up 2 |

Buttons, on the consumer page 0x0C:

| Button | Usage |
|---|---|
| Home | 0x40 |
| Lock | 0x30 |

**Delivery**
- Sends have no acknowledgment; only the barrier proves the connection.
- An interrupted or invalidated connection is rebuilt on the next send, and the barrier runs again.
- A touch in progress when the connection breaks is lost.

## Mac

### SPLKSimulatorHIDInput

`SPLKSimulatorHIDInput` holds one connection per simulator. It's created lazily by `SPLKDeviceSession` for a simulator target, beside `video`.

- **Availability**: it's available when:
  - the loaded CoreSimulator's `CFBundleVersion` is 1155.4 or later;
  - the simulator is found by UDID, as the video source finds it;
  - the barrier answers.

  Older Xcodes have no `dtuhidd`, and they keep device-side input.
- **Touches**: `send(_ events: [SPLKV2InputEvent])` takes the same events Live Control builds for `InjectInput`, so `SPLKLiveInputMapper` serves both backends.
  - It tracks each live `touch_id`, and turns each run of events with the same phase into one digitizer message.
  - Messages carry up to two touches: the two live touches with the lowest IDs, as `pointOne` and `pointTwo`.

  | Touch events | Message |
  |---|---|
  | `BEGAN` with no touch live yet | start |
  | `BEGAN` while touches are live | position |
  | `MOVED` | position |
  | `ENDED` or `CANCELLED`, touches still live | position, carrying the touches that remain |
  | `ENDED` or `CANCELLED`, the last live touches | end, carrying where those touches were |

- **Orientation**: the digitizer's frame is the display's native, portrait one. Points are turned from the interface orientation with `ScreenInfo.orientation`, the inverse of the video's rotation in M7.
- **Buttons**: `press(_ button:)` for Home and Lock. It sends down and then up, 80 ms apart.
- **Text, keys and shake** stay device-side.
  - Text needs Unicode, and the app's own text input handles it.
  - A HID key event would make iOS treat the simulator as having a hardware keyboard, which hides the software keyboard that M9 makes reachable.

### Choosing the backend

| Target | Touches | Buttons | Text, keys, shake |
|---|---|---|---|
| Simulator with `dtuhidd` | host-side | host-side | device-side |
| Simulator without it, or USB device | device-side | none | device-side |

- **Who may send**: host-side input never reaches the phone's lease check. So `SPLKDeviceSession` asks the arbiter first, with the same actor rules as mutating requests. In takeover, only the agent holding it may send.
- **Backgrounded apps**: host-side touches keep working while the inspected app is in the background. The home screen and other apps can be used from Live Control.

### Live Control

- Touches go through the chosen backend.
- The **Device** menu gains:
  - **Home** (⇧⌘H, Simulator.app's shortcut);
  - **Lock** (⌘L).

  Both are enabled in Live Control when the session has host-side input.

### MCP

- **`tap_at`** uses host-side input on simulators, so an agent can tap system alerts and the software keyboard. Its result says which backend it used.
- **`press_button`** is a new write tool:
  - `button` is `home` or `lock`;
  - it works on simulators with host-side input;
  - elsewhere it fails, saying it needs a simulator.

## Verification

- **`SupaLookinTests`**:
  - the touch-to-message translation: one finger, two fingers, a finger lifted mid-gesture, cancel;
  - the orientation turn;
  - the CoreSimulator version gate.
- **`SPLKModesLiveTests`**, against the demo:
  - in Live Control, a click on the video over the software keyboard's key types that letter into the focused field;
  - a click on the demo's button still taps it.
- **By hand**: Home from the Device menu shows the home screen in the video, and a click on the demo's icon brings it back.
- **MCP**: `tap_at` on a keyboard key types it; `press_button` `home` goes home.

## Out of scope

- Indigo input for Xcode 26 and earlier.
- Host-side keyboard events and the hardware-keyboard mode they'd turn on.
- The Digital Crown, the side button's Apple Pay double press, and volume.
- Real devices, which need an XCTest runner or similar.
