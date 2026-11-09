# Protocol v2 M6: agents

## Summary

M6 builds what agents need to operate the phone through MCP:
- semantic actions;
- waiting for the UI to settle;
- hierarchy change events;
- MCP write tools that work under takeover.

It completes the functional layer of `20261109-protocol-v2.md`, apart from video and host-side simulator input (see `20261110-protocol-v2-m5-input.md`). It adds no UI.

## Phone

`SPLKServerSession` adds the capabilities `action.semantic`, `wait.idle` and `events.hierarchy`.

### UI generation

`SPLKUIMonitor` watches the UI on the main thread.

**The generation**:
- The monitor computes a signature of the layer trees of the app's windows: each layer's identity, frame, hidden state, opacity and sublayer count, up to 20,000 layers.
- When the signature changes, the UI generation, a counter starting at 1, goes up by one.
- The generation is computed when someone needs it:
  - `GetHierarchy`;
  - an action or `WaitForIdle` in progress;
  - a subscription to `hierarchy_changed` or `idle`.

  When needed, it's computed at most every 100 ms, from a main run loop observer at `kCFRunLoopBeforeWaiting`.

**Idle**: the UI is idle when no layer has a finite animation and two checks at least 100 ms apart saw the same signature. Endless animations, such as a text caret's blink or a spinner, never finish, so they don't count; their views appearing and disappearing still change the signature.

**`HierarchySnapshot.version`** is the generation at the time of the snapshot, so agents can compare it with events and action results. This replaces the per-session counter of M2.

### Events

| Topic | Event | When |
|---|---|---|
| `hierarchy_changed` | `hierarchy_changed_version` | the generation went up, coalesced by the 100 ms check; and once on subscribing with the current generation |
| `idle` | `idle` | the UI became idle |

### WaitForIdle

`WaitForIdle{timeout_ms}` (read-only) answers `ActionResult{settled, hierarchy_version}`:
- `settled` is true once the UI is idle;
- `settled` is false when `timeout_ms` (default 2,000) passes first.

### PerformAction

`PerformAction{oid, action, text, delta, settle_timeout_ms}` is mutating, so it needs the lease while one is held.
- **The target**:
  - `oid` names a view, or a layer, which acts through the view it backs.
  - An `oid` naming neither fails with `NOT_FOUND` / `object_deallocated`.
- **When it answers**: after the action, it waits for idle like `WaitForIdle` with `settle_timeout_ms`, and answers with the same `ActionResult`.

| Action | Effect |
|---|---|
| `TAP` | `accessibilityActivate()`, if it returns true; otherwise `sendActions(for: .touchUpInside)` for a `UIControl`; otherwise a synthesized tap at the view's center (needs `input.touch`) |
| `LONG_PRESS` | a synthesized touch held 0.6 s at the view's center (needs `input.touch`) |
| `SET_TEXT` | makes the view first responder, clears its text, and inserts `text` through `UIKeyInput`, so editing events and delegates fire as for typing |
| `SCROLL_TO_VISIBLE` | the nearest enclosing `UIScrollView` scrolls the view's bounds visible, without animation |
| `SCROLL_BY` | the view, if a `UIScrollView`, or its nearest enclosing one, moves its content offset by `delta` points, clamped to the content |
| `SWIPE` | a synthesized one-finger drag from the view's center by `delta` points, in 12 steps (needs `input.touch`) |
| `GO_BACK` | the navigation controller nearest the view pops a level, or, with nothing to pop, the view's presented controller is dismissed |

An action that can't apply to the target (`SET_TEXT` on a view without text input, `GO_BACK` with nothing to go back from, a synthesized action without `input.touch`) fails with `FAILED_PRECONDITION` and a reason naming the problem.

## Mac

**`SPLKDeviceSession`** gains `performAction(_:as:)` and `waitForIdle(timeout:)`.

**MCP tools**. Each MCP session gets an identity when its `Server` is created; the arbiter uses it as the takeover holder. New tools:

| Tool | Read-only | Does |
|---|---|---|
| `take_control` | no | `requestTakeover` with an optional `label` |
| `release_control` | no | `releaseTakeover` |
| `tap`, `long_press` | no | `PerformAction` on `oid` |
| `set_text` | no | `PerformAction` `SET_TEXT` with `text` |
| `scroll` | no | `PerformAction` `SCROLL_BY` with `dx`, `dy` |
| `scroll_to_visible` | no | `PerformAction` `SCROLL_TO_VISIBLE` |
| `swipe` | no | `PerformAction` `SWIPE` with `dx`, `dy` |
| `go_back` | no | `PerformAction` `GO_BACK`, on `oid` or the key window's root view |
| `tap_at` | no | a synthesized tap at normalized `x`, `y`, through `InjectInput` |
| `type_text` | no | `InjectInput` text into the focused input |
| `wait_for_idle` | yes | `WaitForIdle` with an optional `timeout_ms` |

- Every write tool renews the session's takeover first.
- Write tools answer with `settled` and the hierarchy version. When the version changed, they say to call `reload` before reading items again.
- An MCP session that never calls `release_control` loses takeover 30 s after its last tool call.

## Verification

- **`SPLKEndToEndTests`, against the demo**:
  - each action changes what the demo records (taps, text, scroll offset, navigation);
  - `WaitForIdle` settles;
  - `hierarchy_changed` follows a change;
  - `HierarchySnapshot.version` matches the action results;
  - a `PerformAction` without the lease while one is held is refused.
- **`SupaLookinTests`**: the MCP tool list includes the write tools with `readOnlyHint` false.
- **By hand**, from an MCP client against Supa Lookin and the demo: `take_control`, `tap`, `set_text`, `release_control`.

## Out of scope

- The Takeover UI: the read-only window, the action log view, "Take Back Control".
- Video and screenshots from video.
