# MCP: what an agent needs to finish a task alone

## Summary

An agent drove SPLK Chat on a jailbroken iPhone 14 through MCP, in Takeover:
- scrolled the chat list to its end;
- opened the last conversation;
- typed "hello" on the system keyboard and sent it;
- went back;
- deleted the conversation by swiping it.

Every step worked, but five things got in its way:
1. It couldn't pick the app; a person had to, in the window.
2. Takeover ended about 12 s in, when the device re-attached over USB for its first screen capture (see "The first screen capture" in `20261118-protocol-v2-m12-jailbreak-input.md`).
3. `go_back` without `oid` found nothing to go back from on a screen pushed inside a tab.
4. `tap_at` returned `settled` before the tap had reached the app, so the agent had to wait on its own.
5. `search` didn't find a row by the name it showed.

This spec fixes all five. It changes MCP and, for `go_back`, `SPLKServerSession`. The Supa Lookin window and the hierarchy panel's search don't change.

## Picking an app

### `list_apps`

Each app gains three fields:

| Field | Value |
|---|---|
| `app_id` | `<device_id>/<bundle_id>`, which `select_app` takes |
| `device_id` | the simulator's UDID, or the USB device's serial number (its UDID) |
| `device_kind` | `simulator` or `device` |

An entry for an app whose SPLKServer is too old or too new still carries only `error`.

### `select_app`

A new tool, with `app_id` required. It does what picking the app in the window does:
- fetches the app's hierarchy;
- makes the app the inspected one;
- if the launch window is showing, opens the workspace window and closes the launch window.

Picking the app that's already inspected reloads it and keeps the hierarchy's expansion and selection, as the window does.

It returns what `get_status` returns.

**Refusals**:
- An `app_id` that `list_apps` doesn't return right now: "No app has this app_id. Call list_apps."
- While another agent has Takeover of the inspected app: "An agent is controlling this app." The window can still pick another app; ending a takeover is the person's call, not another agent's.

## Takeover across a reconnect

When the inspected app's session ends unexpectedly, Supa Lookin reconnects to the same app by itself (`SPLKAppsManager`, every 3 s). Two rules keep an agent's work going through that.

**Waiting**: a tool that needs the inspected app waits for the reconnect, up to 15 s from when the session ended. Only after that does it fail with "No iOS app is being inspected."

**Taking over again**: when an agent calls a tool that needs Takeover, and the reconnected session has none, Supa Lookin takes over again for that agent, with the label it gave, if all of these hold:
- the agent had Takeover of the session that ended;
- that takeover hadn't ended on its own: the agent didn't release it, the person didn't take it back, and it hadn't expired;
- the reconnected session is the same app.

Otherwise the call fails as before, asking for `take_control`.

The window follows: it shows Takeover again once the agent has it.

## `go_back` without `oid`

Without `oid`, the phone goes back from the screen the person sees on top. From the key window's root view controller, it follows:
- the presented view controller, while there is one;
- a tab bar controller's selected view controller;
- a navigation controller's top view controller.

From the controller this reaches, it goes back as it does for an item: it pops the navigation stack the controller belongs to if that has more than one controller, or else dismisses what the controller presents, or else dismisses the controller itself if it's presented. If none applies, it fails with "There's nothing to go back from."

With `oid`, nothing changes.

## Waiting after `tap_at`

Taps that go through the system (`input: "system"`) take a moment to reach the app: the helper's USB round trip, or the simulator's HID daemon. So after such a tap, before waiting for the UI to settle, Supa Lookin waits until the UI generation changes, for up to 400 ms. A tap that changes nothing costs those 400 ms.

Taps that go through the app (`input: "app"`) are delivered before the call returns, so they wait for the UI to settle at once, as before. `type_text` is unchanged.

## Search by text

`search` also matches the text an item shows:
- a label's text;
- a text field's text and placeholder;
- a text view's text.

The text comes from the item's attributes, so it's found only once they've synced, the same condition as `get_item`. Until every item's attributes have synced, for example right after `select_app`, results carry a hint saying how many items' text isn't searchable yet.

Each result gains `text` when the item has any. Results are otherwise unchanged, and matching class name, title and memory address works as before.

The hierarchy panel's search field doesn't change.

## Documentation

`Docs/MCP.md` gains `select_app`, the new `list_apps` fields, the `text` field of search results, and the two reconnect rules.

## Verification

- **`SupaLookinTests`**:
  - `app_id` is formed from the device and the bundle ID for a simulator and for a USB device;
  - search matches a label's text, a text field's placeholder, and still a class name, and results carry `text`;
  - search hints at items whose attributes haven't synced.
- **The e2e demo on the simulator** (`Scripts/e2e-sim.sh` builds the server into it):
  - `go_back` without `oid` pops a screen pushed inside a presented tab, then dismisses the tab.
- **The e2e demo on the simulator, through MCP**: `select_app` by `app_id`, its refusals, search by a label's, a text view's and a table cell's text, and a `tap_at` that returns once the UI it changed has settled.
- **The iPhone 14, through MCP, by an agent**, with Supa Lookin freshly launched:
  - `list_apps`, then `select_app` with SPLK Chat's `app_id`, with nothing picked in the window;
  - `take_control`, then `get_screen`, whose first capture drops the app; the calls after it succeed without a second `take_control`;
  - `tap_at` on a chat row returns once the conversation has opened, with a new `hierarchy_version`;
  - `search` for a contact's name finds its row.

## Out of scope

- Going back without `oid` in apps whose navigation isn't built on UIKit's container view controllers.
- Choosing a simulator or device that has no app with SPLKServer running.
