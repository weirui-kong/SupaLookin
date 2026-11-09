# Protocol v2 M5: device-side input

## Summary

M5 builds the device-side input backend of `20261109-protocol-v2.md`: `InjectInput` replays touches, shakes and text inside the inspected app, as if the user did them.

It is also the spike that spec called for, since its end-to-end tests show which gestures work on iOS 27.

Two backends and the video stay for later, each needing research into private macOS frameworks:
- the Mac-side video (CoreMediaIO for USB devices, SimulatorKit for simulators);
- the host-side simulator input.

The Live Control view is UI work.

## Phone

### Capabilities

`SPLKServerSession` lists these capabilities, each only when its runtime check passes at start-up:
- `input.touch`: touches;
- `input.motion`: shakes;
- `input.text`: text and keys.

### Touches

`SPLKTouchInjector` (Objective-C, in `SPLKServer`, on the main thread) turns each `Touch` into a UIKit touch event, the way KIF and EarlGrey do:
- **One `UITouch` per `touch_id`**, kept from `BEGAN` to `ENDED` or `CANCELLED`.
- **Locations**: a touch's normalized location maps to the key window's coordinates through `ScreenInfo`. Its view is the window's `hitTest` result at `BEGAN`, as UIKit does.
- **Building the event**: each event is the application's touches event (`_touchesEvent`), cleared and refilled with every live touch.
- **The HID event**: the event carries an `IOHIDEvent` digitizer event built with IOKit's `IOHIDEventCreateDigitizerEvent` and `IOHIDEventCreateDigitizerFingerEvent`, one finger child per touch. UIKit's gesture recognizers ignore touch events without one. The functions come from `dlsym`.
- **Delivery**: through `-[UIApplication sendEvent:]`.

**Private API used**, all found at runtime, with touch input disabled when any required one is missing:

| Kind | Names |
|---|---|
| `UITouch` setters | `setWindow:`, `setView:`, `setPhase:`, `setTapCount:`, `_setLocationInWindow:resetPrevious:`, `setTimestamp:`, `_setIsFirstTouchForView:`, `_setHidEvent:`; `setIsTap:` only when present, since iOS 27 no longer has it |
| `UIApplication` | `_touchesEvent` |
| `UITouchesEvent` | `_clearTouches`, `_addTouch:forDelayedDelivery:`, `_setHIDEvent:`. These are checked on the class, since the application may not have created its touches event when the server starts. |
| IOKit | `IOHIDEventCreateDigitizerEvent`, `IOHIDEventCreateDigitizerFingerEvent`, `IOHIDEventAppendEvent`, `IOHIDEventSetIntegerValue` |

When touch input is unavailable, the server logs which symbols it couldn't find.

### Shake and text

- **Shake** sends `motionBegan:withEvent:` and then `motionEnded:withEvent:` (`UIEventSubtypeMotionShake`) to the key window's first responder chain, starting at the first responder, or the key window if there is none. No private API is needed.
- **Text** inserts into the first responder with `insertText:` when it conforms to `UIKeyInput`.
- **Keys**: `DELETE` calls `deleteBackward`, and `RETURN` inserts `"\n"`. The arrow keys, `TAB` and `ESCAPE` move nothing yet and are ignored.

### Delivery

- `InjectInput` is one-way and mutating, so it needs the lease while one is held.
- Its events are replayed in order on the main thread, one per run loop turn. A `MOVED` is dropped when a later `MOVED` for the same touch is already queued.
- An event that can't be delivered (no key window, a touch ID with no `BEGAN`) fails the call with `INVALID_ARGUMENT`. The client sees that on its one-way error stream.

## Mac

- `SPLKDeviceSession.injectInput(_:as:)` sends `InjectInput` one-way, with the arbiter's lease ID for the actor.
- During Live Control, the window is that actor.

## Verification

`SPLKEndToEndTests`, against the demo:
- a tap on the button runs its action;
- a tap on the custom view fires its tap recognizer;
- a one-finger drag over the table view scrolls it;
- a two-finger pinch is delivered without error;
- a shake reaches the view controller;
- text typed into the focused text field arrives, and `DELETE` removes a character;
- `InjectInput` without the lease while one is held is refused.

The demo records what reached it, and the tests read it with `InvokeMethod`.

## Out of scope

- Video, Mac-side capture and in-app capture.
- Host-side simulator input.
- The Live Control view.
