# MCP server

## Summary

Supa Lookin hosts an MCP server so AI agents can read the UI of the iOS app being inspected. It shares the app's current session: the agent sees the same connected app, hierarchy and selection as the window, and never opens a connection of its own.

Phase 1 is read-only. No tool changes the iOS app, and the only one that touches the Mac UI is `reload`, through the window's own reload. Tools that operate on the app come in a later phase.

## Transport

- Streamable HTTP (MCP 2025-11-25, stateful sessions with SSE) at `http://127.0.0.1:47200/mcp`, served by [FlyingFox](https://github.com/swhitty/FlyingFox) through the official [swift-sdk](https://github.com/modelcontextprotocol/swift-sdk)'s `StatefulHTTPServerTransport`.
- Listens on IPv4 loopback only. The port stays clear of LookinServer's 47164–47169 (simulator) and 47175–47179 (USB) and can be overridden with the `mcpPort` user default.
- One transport and one `Server` per MCP session, keyed by the `Mcp-Session-Id` the transport assigns. At most 16 sessions are kept; the oldest is dropped beyond that. `DELETE` ends a session.
- The SDK's default validation stays on: localhost `Origin`/`Host` (DNS-rebinding protection), `Accept`, `Content-Type`, protocol version and session checks.

## Authentication

Every request must carry `Authorization: Bearer <token>`; otherwise it gets `401` before reaching the transport. The token is 32 random bytes, hex-encoded, created on first launch and kept in user defaults (`mcpToken`). Any local process can reach a loopback port, so the token is what keeps other software out.

## Settings

The server is on by default and starts when the app finishes launching. Preferences gets an MCP row:

- an on/off popup
- the status: the URL when running, or the error (e.g. the port is in use)
- **Copy Command**, which copies `claude mcp add --transport http supalookin <url> --header "Authorization: Bearer <token>"`

## Tools

All tools carry `readOnlyHint: true`. Items are identified by `oid`, the item's layer oid; tools that take an `oid` also accept its view oid. Every tool except `get_status` and `list_apps` needs an inspected app with a loaded hierarchy and otherwise returns an error saying so.

| Tool | Arguments | Returns |
|---|---|---|
| `get_status` | — | whether an app is inspected; its name, bundle ID, device, OS and LookinServer version; the number of items; the selected item's `oid` |
| `list_apps` | — | the inspectable apps found now (same lookup as the toolbar App popover), marking the inspected one |
| `get_hierarchy` | `root_oid?`, `max_depth?` (default unlimited), `limit?` (default 500) | the item tree from the root windows, or from `root_oid`. Each node: `oid`, `view_oid`, `class`, `title`, `frame` (in its superview), `hidden`, `alpha`, `view_controller`, `children`. Output stops at `limit` nodes and says it was truncated. |
| `get_item` | `oid` | the node fields plus `frame_in_window`, `bounds`, and every attribute group, section and attribute shown in the dashboard, with values as JSON (numbers, booleans, strings, `{x,y,width,height}` geometry, colors as RGBA strings, enums by name) |
| `get_screenshot` | `oid`, `include_subviews?` (default true) | the item's screenshot as a PNG image, scaled down so its longer side is at most 1024 px |
| `search` | `query`, `limit?` (default 50) | items matching the hierarchy panel's search, as flat node summaries |
| `get_selection` | — | the item selected in the window, if any, as `get_item` returns it |
| `reload` | — | reloads the hierarchy through the same path as the Reload menu item and returns once the new hierarchy is in. Unlike the menu item, it refuses while a sync is running instead of stopping it, and returns errors instead of showing an alert. |

## Shared session

- Tools read `LKStaticHierarchyDataSource` and `LKAppsManager`, which run on the main actor. Each handler hops to the main actor, builds its JSON there, and returns it to the SDK's actor.
- No tool sends `Hierarchy`, `HierarchyDetails` or attribute requests of its own. `LKConnectionManager` drops an older pending request when a newer one of the same type is sent, so a parallel fetch would cancel the window's sync. `reload` reuses the window's reload instead.
- `list_apps` sends the same `App` requests as the App popover. If both run at the same moment, the earlier one fails as it already would between two popovers.

## Verification

- `SupaLookinTests`: the bearer check, session routing, the SSE body adapter, and the JSON built for a hierarchy, an item's attributes and search results.
- An end-to-end test starts the server on a spare port and runs `initialize`, `tools/list` and `tools/call get_status` over HTTP.
- Against the demo iOS app: each tool from Claude Code via the copied command, while the window keeps syncing normally.

## Out of scope for Phase 1

- Anything that changes the iOS app (attribute edits, method calls, gesture toggles) or drives the Mac UI (selection, focus, expansion).
- MCP resources and prompts.
- `.lookin` documents opened in read windows.
