# Protocol v2 M7: Mac-side video

## Summary

M7 builds the Mac-side video of `20261109-protocol-v2.md`: the phone's screen captured on the Mac, with nothing running in the app.
- **Simulators**: the CoreSimulator framebuffer.
- **USB devices**: CoreMediaIO screen capture devices, read through AVFoundation.

The future Live Control view and agents both read the same source. M7 gives agents a whole-screen screenshot read from the video.

M7 adds no UI. In-app capture (`video.inapp.h264`) and host-side simulator input stay for later.

## Phone

`AppSummary` gains `simulator_udid` (field 9).
- On a simulator, the server fills it from `SIMULATOR_UDID` in its environment.
- On a device, it's empty.

The Mac uses it to find the simulator the app runs in, since every simulator shares the same localhost ports.

## Mac

### Targets

`SPLKDeviceSession` gains `target`, set by `SPLKConnectionManager` when it connects:

| Target | Set from |
|---|---|
| `simulator(udid)` | the port is a simulator port; `udid` is the `ServerHello`'s `simulator_udid` |
| `usbDevice(serialNumber)` | the port is on a USB device; `serialNumber` is the `SerialNumber` usbmuxd reported when the device attached |

### Video sources

`SPLKVideoSource` is a base class with one subclass per target kind. `SPLKDeviceSession.video` creates the one its target needs on first use.

- **Starting and stopping**: `start()` and `stop()` are counted, so every user starts and stops independently. Capture runs while the count is above zero.
- **Frames**: `frames` publishes `SPLKVideoFrame`s, and holds the latest one. A frame is a `CVPixelBuffer` (32-bit BGRA) plus the host time it arrived.
- **Orientation**: frames come in whatever orientation the capture gives. Consumers turn them to the app's interface orientation with `ScreenInfo`, the same mapping input uses:
  - when a frame's aspect (portrait or landscape) already matches `ScreenInfo.size`, it's used as is;
  - otherwise it's rotated, clockwise for `LANDSCAPE_LEFT` and counterclockwise for `LANDSCAPE_RIGHT`.
- **Failures**: `start()` throws `SPLKVideoError` with a reason the UI can show. The reasons are:
  - CoreSimulator can't be loaded;
  - the simulator isn't booted;
  - no display matches;
  - camera access was denied;
  - the device's capture device didn't appear in time.

#### Simulator

`SPLKSimulatorVideoSource` reads the simulator's framebuffer through CoreSimulator (private), as Simulator.app did.

1. **Loading CoreSimulator**:
   - It loads `/Library/Developer/PrivateFrameworks/CoreSimulator.framework`.
   - It opens `SimServiceContext` for the active developer directory: `DEVELOPER_DIR` if set, or else `xcode-select -p`.
2. **Finding the device**: in the default device set, it takes the device whose UDID is the target's. Without a UDID, it takes the only booted device, if there is exactly one.
3. **Choosing a display**:
   - The device's I/O ports are XPC proxies. Their descriptors that conform to `SimDisplayIOSurfaceRenderable` and `SimScreen`, and return a `framebufferSurface`, are the displays.
   - It picks the display whose pixel size, in either orientation, equals the app's `ScreenInfo` size × scale.
   - If none matches, it picks the main display: the lowest `screenID` among screens of type 0, the built-in panels.
   - A device with two panels, such as a foldable, needs the match.
4. **Frames**:
   - The framebuffer is an `IOSurface` that the simulator redraws in place. The source wraps it in a `CVPixelBuffer` once, without copying.
   - It registers `registerScreenCallbacksWithUUID:callbackQueue:frameCallback:surfacesChangedCallback:propertiesChangedCallback:`. Each frame callback publishes a frame, at up to 60 fps.
   - `surfacesChanged` re-reads the framebuffer and wraps the new surface.
   - Stopping unregisters the callbacks with `unregisterScreenCallbacksWithUUID:`.

Proxies raise Objective-C exceptions for selectors they don't implement, and Swift can't catch those. So every call is checked with `respondsToSelector:` first, and values are read by typed message sends, never by key-value coding.

#### USB device

`SPLKDeviceVideoSource` captures a USB device the way QuickTime's device mirroring does.

1. **Camera access**: it asks for camera access (`AVCaptureDevice.requestAccess(for: .video)`). Without it, AVFoundation hides capture devices. The app adds `NSCameraUsageDescription` and the hardened runtime's `com.apple.security.device.camera` entitlement.
2. **Enabling the capture device**: it sets `kCMIOHardwarePropertyAllowScreenCaptureDevices` to 1 on the CoreMediaIO system object, once per process. The device's screen then shows up as an external, muxed `AVCaptureDevice` after a few seconds.
3. **Finding the device**: it looks for the external, muxed `AVCaptureDevice` whose `uniqueID`, without dashes and ignoring case, equals the target's serial number, also without dashes. It looks again every 250 ms, for up to 10 s.
4. **Capturing**: an `AVCaptureSession` with the device's input and an `AVCaptureVideoDataOutput`:
   - BGRA pixels;
   - late frames discarded;
   - frames delivered on a serial queue and published on the main actor.
5. **Stopping**: stopping the session leaves screen capture devices allowed for the rest of the process.

### Snapshots

`snapshot(screen:)`:
1. returns the latest frame, turned to the interface orientation, as a `CGImage`;
2. if the source isn't running, starts it, waits for the first frame, and stops it again.

### MCP

A new read-only tool, `get_screen`:
- It answers the whole screen as a PNG, at most 1024 px on its longer side, like `get_screenshot`.
- It takes the image from the session's video source.
- When the source fails, it falls back to the app's own screenshot from `GetAppInfo` with images. Unlike the video, that image lacks system UI such as alerts and the keyboard.
- The answer says which one it used.

## Verification

- **`SPLKEndToEndTests`**: `ServerHello.app.simulator_udid` equals the simulator's UDID.
- **`SPLKVideoLiveTests`** in `SupaLookinTests`, run inside the app with `TEST_RUNNER_SPLK_VIDEO_E2E=1` against the demo on a booted simulator:
  - the session's target carries the simulator's UDID;
  - the source starts, and publishes frames while the screen redraws (the simulator's appearance is switched to dark and back);
  - a snapshot is written to `TEST_RUNNER_SPLK_VIDEO_OUT`.
- **By hand**, with that test on the iPhone Duo simulator:
  - the snapshot comes from the panel matching the demo's screen;
  - after rotating the simulator, the snapshot shows the demo upright;
  - with a text field focused and the on-screen keyboard shown, the snapshot shows the keyboard.
- **`SupaLookinTests`**:
  - the orientation rule;
  - the display choice, over the iPhone Duo's recorded screens;
  - serial number matching;
  - `get_screen` listed as read-only.
- **USB devices** are verified once a device is available. M7 builds the source but doesn't prove it on hardware.

## Out of scope

- The Live Control view and showing the video in the window.
- In-app capture and the `VIDEO` channel.
- Host-side simulator input.
- Audio.

## Update: finding a device's screen on macOS 27 (see `20261110-protocol-v2-m10-device-input.md`)

Verified on an iPhone 12 mini (iOS 27.2):
- **The capture device's `uniqueID` is a random UUID**, not the UDID. Its `localizedName` is the device's name.
- **Matching order** for `SPLKDeviceVideoSource`:
  1. the UDID, as before;
  2. the name CoreDevice reports for that UDID (`devicectl list devices`);
  3. the only iOS screen, when just one is attached.
- **The first frame** arrives a moment after capture starts: 1082×2340 at up to 60 fps.
- **`SPLKDeviceVideoLiveTests`** checks this against a device given by `TEST_RUNNER_SPLK_DEVICE_SERIAL`.
