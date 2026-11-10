# Protocol v2 M8: the modes in the window

## Summary

M8 builds the UI for the three modes of `20261109-protocol-v2.md` (Inspect, Live Control and Takeover), on top of `SPLKControlArbiter` (M4), device-side input (M5) and Mac-side video (M7).

- **Switching**: a mode menu in the toolbar, left of Reload.
- **The transition**: leaving Inspect, the window first animates the hierarchy away, then shows the video.
  1. The expanded hierarchy collapses.
  2. The 3D preview turns flat.
  3. The phone's screen becomes the live video.
- **One window**: Live Control and Takeover happen in the window you're using. No new window opens.
- **Video only**: both modes show only the phone's live video.
  - The hierarchy stays loaded, so MCP tools keep working, but it isn't shown.
  - Returning to Inspect shows it again.

## Mode menu

**The toolbar item**:
- It's a new item, `SPLKToolBarIdentifier_Mode`, first in the toolbar, so it sits left of Reload.
- It's a pull-down button showing the current mode's icon and name.

| Mode | Icon (SF Symbol) | Label |
|---|---|---|
| Inspect | `square.3.layers.3d` | Inspect |
| Live Control | `hand.tap` | Live Control |
| Takeover | `sparkles` | the agent's label, such as "Claude Code" |

**Its menu**:

| Item | Without takeover | During takeover |
|---|---|---|
| Inspect | enabled, checked in Inspect | disabled |
| Live Control | enabled, checked in Live Control | disabled |
| separator | | |
| Takeover | disabled, with the tooltip "An agent starts Takeover by calling take_control." | **End Takeover by \<label\>**, enabled |

- **Takeover is started only by agents.** When an MCP session calls `take_control`, from Inspect or from Live Control, the window switches to Takeover by itself.
- **End Takeover** is the person's forced interrupt. It calls `takeBack()`:
  - the agent loses its lease;
  - its next write tool fails with `lease_revoked`;
  - the window returns to Inspect.
- **The window follows the arbiter.** The menu and the window both read `SPLKControlArbiter.modeSubject` of the inspected app's session. A choice changes the arbiter's mode, and the window's transition follows that change:
  - Live Control calls `startLiveControl()`;
  - Inspect calls `stopLiveControl()`, so the lease is released before the window animates back;
  - End Takeover calls `takeBack()`.
  - A takeover that ends any other way (release, expiry, the phone dropping the lease) also returns the window to Inspect.
  - Without an inspected app, the menu is disabled and shows Inspect.

**The menu bar**:
- **View › Mode** offers the same choices:
  - Inspect (⌃⌘I)
  - Live Control (⌃⌘L)
  - End Takeover (⌃⌘.)

  ⌘1–⌘5 stay with Hierarchy Depth.
- A new **Device** menu, between View and Window, holds **Shake** (⌃⌘Z, Simulator's shortcut). It's enabled only in Live Control.

## The transitions

`SPLKModeTransition` runs inside `SPLKStaticViewController`. Changes of mode that arrive while a transition is running wait for it to finish.

### Inspect → Live Control or Takeover

The video source starts when the transition starts, so its first frame is ready by the hand-off. The transition has three phases, about 1.1 s in total:

1. **Collapse** (0.35 s):
   - The window remembers each item's `isExpanded`, the preview's rotation, and its dimension.
   - It then collapses every item to its window.
   - The hierarchy panel folds as it does today. The preview's layers sink into their windows through the same `SCNTransaction` animations that folding uses now.
2. **Flatten** (0.4 s, ease in-out):
   - The preview turns face-on (`setRotation(.zero, animated:)`) and switches to 2D, so the layers' z spacing goes to zero.
   - This is the 3D transform: the exploded phone becomes a flat screen facing the user.
3. **Hand-off** (0.35 s, ease in-out):
   - The window takes a `snapshot()` of the preview and puts it in a layer over the preview, at the rect where the app's screen appears on screen.
   - The real preview is hidden.
   - At the same time:
     - the hierarchy panel slides out to the left;
     - the dashboard slides out to the right;
     - the snapshot layer moves and scales to the video's rect;
     - the snapshot layer crossfades to the live video.

When the hierarchy isn't loaded, or the preview shows nothing, phases 1 and 2 are skipped. Phase 3 then fades from the preview to the video.

### Live Control ↔ Takeover

The video is already showing. Only the overlay changes: the status pill described under Video modes, and whether input is accepted.

### Back to Inspect

The return runs the same phases in reverse.

1. **Hand-off back**:
   - The latest video frame shrinks to the preview's screen rect, while the panels slide back in.
   - The frame then crossfades to the preview, flat and in 2D.
2. **Reload**: the window reloads the hierarchy as Reload does, keeping state, since the app changed while the hierarchy was hidden.
3. **Unflatten and expand**: once the hierarchy arrives, the preview returns to the dimension and rotation it had. Every item that still exists returns to its remembered `isExpanded`. Both animate as they do today.

The video source stops once the hand-off back is done.

If the reload fails, the window stays in Inspect with the flat preview and shows the error as Reload does.

### Without animation

The window switches without animation in these cases:
- the inspected app disconnects, which returns the window to Inspect;
- the user picks another app from the App button, which returns the window to Inspect first;
- Reduce Motion is on in System Settings, in which case the panels and video crossfade instead.

## Video modes

`SPLKLiveViewController` fills the area where the hierarchy, preview and dashboard were. The console and measure panels are hidden too.

- **The video**:
  - It's drawn by `SPLKVideoView`, a layer-backed view whose layer shows each frame's `IOSurface` as its contents.
  - It's aspect-fit in the area, with a 24 pt margin, a corner radius scaled from the device (the screen's corner radius isn't known, so it uses 6% of the shorter side), and a soft shadow.
- **Orientation**:
  - The view subscribes to the `screen` topic.
  - It rotates frames by `SPLKVideoSource.rotation`, and turns the video when the app's orientation changes.
- **The status pill**: a small pill sits centered above the video.
  - In Live Control, it reads "Live Control".
  - In Takeover, it reads "\<label\> is controlling the app".

  There's no action log in the window.
- **When the video fails**:
  - The area shows the `SPLKVideoError` and its suggestion, with **Try Again**.
  - The mode doesn't change, and the mode menu still returns to Inspect.
- **The toolbar**:
  - In video modes, every item except the mode menu is disabled.
  - Reload, Fast Mode, the App button, Dimension, Rotation, View, Scale, Measure and Console belong to Inspect.

### Live Control input

Picking Live Control calls `startLiveControl()`, and the transition starts once the arbiter is in Live Control. If that fails, the window stays in Inspect and shows the error. Takeover by an agent is the usual reason.

Input goes to the phone through `SPLKDeviceSession.injectInput(_:as: .window)`, the device-side backend of M5. It reaches the app's own windows, not system UI.

`SPLKLiveInputMapper` turns events in the video view into `InputEvent`s:
- **Positions**: points are normalized to the video rect in the app's interface orientation, as `InjectInput` expects. Events outside the video rect are ignored.

| Mac | Phone |
|---|---|
| Left mouse down, drag, up | one touch: `BEGAN`, `MOVED`, `ENDED`. `MOVED` events are coalesced to one per display frame. |
| Trackpad pinch (magnify) | two touches around the pointer, whose distance scales with the magnification |
| Trackpad rotate | two touches around the pointer, turning by the rotation |
| Option-drag | two touches mirrored around the video's center, as Simulator.app did |
| Scroll (trackpad or wheel) | a one-finger drag from the pointer by the scroll delta. Trackpad scrolls follow their gesture phases, and momentum is ignored. Wheel notches become short drags of 40 points. |
| Typing, while the video view is first responder | text events. Delete, Return, Tab, Escape and the arrow keys become their `Key` codes; the phone acts on `DELETE` and `RETURN` (see M5). Command shortcuts go to the menus as usual. |
| **Device › Shake** (⌃⌘Z) | a shake |

- A mode change ends any touch in progress with `CANCELLED`.
- In Takeover, the video view accepts no input. The pointer shows as not-allowed over the video.

## Code

| New | Where |
|---|---|
| `SPLKModeToolbarItem` | `SupaLookin/Toolbar/` |
| `SPLKModeTransition` | `SupaLookin/Static/` |
| `SPLKLiveViewController`, `SPLKVideoView`, `SPLKLiveInputMapper` | `SupaLookin/Live/` |

- `SPLKStaticViewController` owns the live view controller and runs the transitions.
- `SPLKStaticWindowController` adds the toolbar item and disables the other items in video modes.

## Verification

- **`SupaLookinTests`**:
  - `SPLKLiveInputMapper`:
    - normalized points in a letterboxed video rect;
    - ignoring events outside it;
    - landscape;
    - pinch and option-drag pairs;
    - scroll-to-drag;
    - coalescing.
  - The mode menu's items and their states in each arbiter mode, including End Takeover.
- **`SPLKModesLiveTests`** in `SupaLookinTests`, run inside the app with `TEST_RUNNER_SPLK_VIDEO_E2E=1` against the demo on a booted simulator. It drives the real window:
  - flat, the preview's projected screen rect has the phone's aspect, and its snapshot is the phone's screen;
  - Inspect → Live Control, from 3D with an expanded hierarchy:
    - every item collapses;
    - the preview is 2D;
    - the panels are hidden and the live view is shown;
    - video frames arrive;
    - Reload is disabled, and the menu bar offers only Inspect, Live Control and Shake;
  - a click on the video over the demo's button taps it, and Shake reaches the demo;
  - a takeover from Live Control keeps the video and turns input off;
  - End Takeover returns to Inspect: the panels come back, the preview is 3D again, the same items are expanded, and the agent's lease is gone;
  - a takeover from Inspect switches the window, and its release switches it back.
- **By hand**, against the e2e demo on a simulator:
  - The transitions look right: no jumps between the collapse, the flattening and the hand-off, in both directions.
  - In Live Control:
    - dragging scrolls the table;
    - pinching and option-dragging reach the demo;
    - typing reaches the focused text field;
    - Device › Shake reaches the demo.
  - Rotating the simulator turns the video, and clicks still land where they're aimed.
  - The status pill names the agent during an MCP `take_control`, and the agent's next `tap` after End Takeover fails with `lease_revoked`.
  - MCP `get_hierarchy` works while the window shows video.
  - With Reduce Motion on, the modes crossfade.

## Out of scope

- An action log or touch marks in the window.
- The on-device takeover indicator of `20261109-protocol-v2.md`.
- Host-side simulator input, which would reach system UI.
- Recording the video.
