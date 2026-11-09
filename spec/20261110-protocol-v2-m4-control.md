# Protocol v2 M4: control leases and events

## Summary

M4 builds the functional layer of the Control section of `20261109-protocol-v2.md`:
- leases on the phone;
- event subscriptions;
- the Mac's arbitration between the window, Live Control and MCP sessions.

It adds no UI. The on-device indicator, the window's read-only state and "Take Back Control" arrive with the UI work, and call the APIs below.

## Phone

`SPLKServerSession` adds the capabilities `control.lease` and `events`.

### Leases

- **`AcquireControl{kind, holder_label, preempt}`**:
  - With no lease held, it creates one: a random 16-byte `lease_id`, owned by the requesting session.
  - With a lease held, it fails with `FAILED_PRECONDITION` / `lease_held`, unless `preempt` is set. Then it replaces the held lease and publishes `lease_released` for the old one before `lease_acquired` for the new one.
  - It answers with the new `ControlLease`.
- **`ReleaseControl{lease_id}`**: releases the lease if the ID matches, and answers `Empty` either way.
- **Enforcement**: every request whose method is mutating is checked.

  | Lease state | Request's `lease_id` | Result |
  |---|---|---|
  | none held | empty | allowed |
  | none held | non-empty | `PERMISSION_DENIED` / `lease_revoked` |
  | held | empty | `PERMISSION_DENIED` / `lease_required` |
  | held | matches | allowed |
  | held | another ID | `PERMISSION_DENIED` / `lease_revoked` |

- **Leases end with their session.** `SPLKRequestHandler` gains `sessionDidEnd(_:)` (default: nothing), which `SPLKHost` calls when it closes a session. The server releases that session's lease and publishes `lease_released`.

### Events

`Subscribe{topics}` streams `Event`s for these topics:

| Topic | Event | When |
|---|---|---|
| `app_state` | `app_in_foreground` | on `didBecomeActive` (true) and `willResignActive` (false), and once on subscribing with the current state |
| `screen` | `screen` | when the key window's orientation or size changes, and once on subscribing |
| `control` | `lease_acquired`, `lease_released` | as above, and once on subscribing with the current lease, if any |

- Unknown topics are ignored.
- A subscription has no deadline. The client sends `deadline_ms = 4294967295`, and both ends treat the stream as alive until either side ends it.
- `Subscribe` and `ReleaseControl` are exempt from the background check, since they're how a client learns the app came back and how it lets go. Every other request still fails with `app_in_background` while the app is inactive.

## Mac

### SPLKDeviceSession

`SPLKDeviceSession` gains:
- `acquireControl(kind:holderLabel:preempt:)` and `releaseControl(_:)`;
- `events(topics:)`, an `AsyncThrowingStream` of `SPLKV2Event`;
- a lease ID on its mutating calls, supplied by the arbiter.

### SPLKControlArbiter

`SPLKControlArbiter` is one per `SPLKDeviceSession`, on the main actor. It owns the mode and decides who may change the phone.

| Mode | Phone lease | The window may mutate | An MCP session may mutate |
|---|---|---|---|
| `inspect` | none | yes, without a lease | no (`PERMISSION_DENIED` / `lease_required`) |
| `liveControl` | the window's, `LIVE_CONTROL` | yes, with its lease | no |
| `takeover(session)` | that MCP session's, `TAKEOVER` | no (`PERMISSION_DENIED` / `takeover_active`) | only `session`, with its lease |

Operations:

| Operation | Effect |
|---|---|
| `startLiveControl()` | In `inspect`, acquires a `LIVE_CONTROL` lease. In `takeover`, refused. |
| `stopLiveControl()` | Back to `inspect`, releasing the lease. |
| `requestTakeover(session:label:)` | Acquires a `TAKEOVER` lease with `preempt`, so it ends Live Control. Refused while another MCP session holds takeover. |
| `renewTakeover(session:)` | Required at least every 30 s. A takeover not renewed for 30 s is released, back to `inspect`. |
| `releaseTakeover(session:)` | Back to `inspect`. |
| `takeBack()` | The human override. Ends any takeover and returns to `inspect`; the MCP session's next mutating call fails with `lease_revoked`. |

- **Publishing**: the arbiter publishes its mode, and an action log entry (method, MCP session, time) for every mutating call an MCP session makes.
- **Mode follows the phone**:
  - The arbiter subscribes to the `control` topic.
  - A `lease_released` for its own lease (the phone ended the session, or another client preempted) returns it to `inspect`.
- **The window's existing mutating calls**, through `SPLKInspectableApp`, go through the arbiter as the window. During takeover they fail with v1-style `NSError`s carrying the status's title and detail.

## Verification

- **`SPLKEndToEndTests`, against the demo**:
  - acquire and release;
  - every row of the enforcement table;
  - `lease_held` without `preempt`, and preemption;
  - a lease released when its session closes;
  - `app_state` events across backgrounding;
  - `control` events.
- **`SupaLookinTests`**, for the arbiter against a fake device session:
  - every operation and mode transition;
  - refusal of a second takeover;
  - expiry after 30 s without renewal (with an injected clock);
  - `takeBack`;
  - the window refused during takeover;
  - the action log.

## Out of scope

- The on-device indicator and the window's controls (UI work).
- `hierarchy_changed` and `idle` (M6), input (M5).

## Update: implementation notes

- **`OneOf_Call.methodName`** in `SPLKProtocol` gives each call its name from the v2 Methods table. The action log records it.
- **The arbiter holds its device session weakly**, since the session owns the arbiter.
- **Refusals carry localized text** (en, zh-Hans) in their status title and detail. The window's errors show them through the same v1-style `NSError`s as other failures.
- **Backgrounded apps**: once iOS suspends an app in the background, it answers nothing, and requests time out as in v1. The background end-to-end test accepts either `app_in_background` or `DEADLINE_EXCEEDED`.
