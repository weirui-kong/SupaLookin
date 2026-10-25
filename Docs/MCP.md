# Supa Lookin MCP Server

Supa Lookin includes a built-in [Model Context Protocol](https://modelcontextprotocol.io) (MCP) server. It lets AI agents such as Claude Code, Cursor or VS Code read the UI of the iOS app you are inspecting: its view hierarchy, the attributes of every view and layer, and their screenshots.

The server shares Supa Lookin's current session. The agent sees the same app, hierarchy and selection as the Supa Lookin window, and the tools read what the window has already loaded instead of fetching the hierarchy again.

> **Phase 1 is read-only.** No tool changes the iOS app. The one tool that affects Supa Lookin is `reload`, which reloads the hierarchy the same way as the Reload menu item. Tools that operate on the app, such as editing attributes, will be added in a later phase.

## Requirements

- Supa Lookin running on macOS 14 or later.
- An iOS app that integrates [LookinServer](https://github.com/QMUI/LookinServer), running on a simulator or a USB-connected device and opened in Supa Lookin.

## Quick start

1. Open Supa Lookin and pick your iOS app. The MCP server starts automatically.
2. Open **Supa Lookin › Preferences…** (⌘,). The **MCP Server** row shows the server's status, for example `Running at http://127.0.0.1:47200/mcp`.
3. Click **Copy Command**. This copies a ready-to-run command that already contains your access token:

   ```bash
   claude mcp add --transport http supalookin http://127.0.0.1:47200/mcp --header "Authorization: Bearer <token>"
   ```

4. Run it in a terminal, then ask your agent something like *"Use Supa Lookin to describe the layout of the current screen."*

## Connecting other clients

Other clients need the **Streamable HTTP** transport and a way to send custom request headers. Use:

| Setting | Value |
|---|---|
| URL | `http://127.0.0.1:47200/mcp` |
| Header | `Authorization: Bearer <token>` |

Get the token from the command that **Copy Command** copies. The snippets below follow the [Cursor](https://cursor.com/docs/context/mcp) and [VS Code](https://code.visualstudio.com/docs/copilot/customization/mcp-servers) documentation. Check it if your version uses a different format.

**Cursor** (`~/.cursor/mcp.json` or `.cursor/mcp.json` in a project):

```json
{
  "mcpServers": {
    "supalookin": {
      "url": "http://127.0.0.1:47200/mcp",
      "headers": { "Authorization": "Bearer <token>" }
    }
  }
}
```

**VS Code** (`.vscode/mcp.json`):

```json
{
  "servers": {
    "supalookin": {
      "type": "http",
      "url": "http://127.0.0.1:47200/mcp",
      "headers": { "Authorization": "Bearer <token>" }
    }
  }
}
```

## Settings

| What | How |
|---|---|
| Turn the server on or off | **Preferences › MCP Server**. It is on by default. |
| Change the port | `defaults write icu.retrouvailles.supalookin mcpPort -int 47201`, then turn the server off and on again in Preferences. The default port is 47200. |
| Create a new token | Quit Supa Lookin, run `defaults delete icu.retrouvailles.supalookin mcpToken`, and open Supa Lookin again. Clients that used the old token must be updated. |

The default port is chosen to stay clear of the ports LookinServer itself uses (47164–47169 for simulators, 47175–47179 for USB devices).

## Tools

In Phase 1, every tool is annotated `readOnlyHint: true`. Results are returned as JSON text, except `get_screenshot`, which returns a PNG image.

### Identifying items

Every view or layer in the hierarchy is an **item**, identified by its `oid`, which is the oid of the item's `CALayer`. Items backed by a `UIView` also have a `view_oid`, and every tool that takes an `oid` accepts either one.

The tools only know the hierarchy Supa Lookin last loaded. After the iOS app's UI changes, call `reload` and read the hierarchy again.

### Item summary

`get_hierarchy` and `search` describe each item with these fields:

| Field | Meaning |
|---|---|
| `oid` | The item's identifier |
| `view_oid` | The oid of its `UIView`, if any |
| `class` | Class name, including the module prefix for Swift classes |
| `title` | The name shown in Supa Lookin's hierarchy panel |
| `frame` | `{x, y, width, height}` in its superview's coordinates |
| `hidden` | Whether the item is hidden |
| `alpha` | Its opacity |
| `view_controller` | The class of the view controller whose root view this is, if any |

Numbers that the device reports as NaN or infinity are returned as `null`.

### `get_status`

Whether an app is being inspected, and which one. Call this first.

```json
{
  "inspecting": true,
  "app": {
    "name": "MyApp",
    "bundle_id": "com.example.myapp",
    "device": "iPhone 17 Pro",
    "os": "26.1",
    "server_version": "1.2.8"
  },
  "item_count": 235,
  "selected_oid": 22
}
```

When no app is being inspected, it returns `{"inspecting": false, "hint": "…"}`.

### `list_apps`

The inspectable apps found right now on simulators and USB devices, looked up the same way as the App popover in Supa Lookin's toolbar. The one being inspected has `"inspecting": true`. An app whose LookinServer version is not supported carries an `error` instead.

```json
{
  "apps": [
    { "name": "MyApp", "bundle_id": "com.example.myapp", "device": "iPhone 17 Pro", "os": "26.1", "server_version": "1.2.8", "inspecting": true }
  ]
}
```

### `get_hierarchy`

The item tree, starting from the app's windows or from a given item.

| Argument | Type | Default | Notes |
|---|---|---|---|
| `root_oid` | integer | — | Start from this item instead of the windows |
| `max_depth` | integer | unlimited | Levels below the root to include |
| `limit` | integer | 500 | Maximum number of items, between 1 and 5000 |

```json
{
  "items": [
    {
      "oid": 1, "class": "UIWindow", "title": "UIWindow",
      "frame": { "x": 0, "y": 0, "width": 402, "height": 874 },
      "hidden": false, "alpha": 1,
      "children": [
        { "oid": 8, "class": "UITransitionView", "title": "UITransitionView", "frame": { "x": 0, "y": 0, "width": 402, "height": 874 }, "hidden": false, "alpha": 1, "children_count": 1 }
      ]
    }
  ],
  "node_count": 2,
  "truncated": false
}
```

`children_count` appears when an item has more children than are listed, because of `max_depth` or `limit`. `truncated` is `true` when `limit` stopped the output. Large apps have thousands of items, so a good strategy is to read a few levels first and then call `get_hierarchy` again with `root_oid` on the part you need.

### `get_item`

One item in full.

| Argument | Type | Notes |
|---|---|---|
| `oid` | integer | Required |

It returns the item summary plus:

| Field | Meaning |
|---|---|
| `frame_in_window` | The frame in its window's coordinates |
| `bounds` | Its bounds |
| `children_count` | The number of direct children |
| `attribute_groups` | Every attribute shown in Supa Lookin's attribute panel, grouped by card and section |

Attributes arrive while Supa Lookin syncs, after the hierarchy. Until an item's attributes have synced, `attribute_groups` may be missing them. With **Fast Mode** on, Supa Lookin syncs only the items that are expanded in its hierarchy panel, so expand the part you need first.

Attribute values use JSON types: numbers, booleans and strings; `{x, y}`, `{width, height}`, `{x, y, width, height}` and `{top, left, bottom, right}` for geometry; colors as RGBA strings such as `"(255, 0, 0, 0.50)"`; enums by name, such as `"NSTextAlignmentCenter"`; and Auto Layout constraints as readable equations.

```json
{
  "oid": 42, "view_oid": 43, "class": "UILabel", "title": "UILabel",
  "frame": { "x": 0, "y": 0, "width": 370, "height": 15.67 },
  "frame_in_window": { "x": 16, "y": 132, "width": 370, "height": 15.67 },
  "bounds": { "x": 0, "y": 0, "width": 370, "height": 15.67 },
  "hidden": false, "alpha": 1, "children_count": 0,
  "attribute_groups": [
    {
      "title": "UILabel",
      "sections": [
        { "title": "Text", "attributes": [{ "title": "Text", "value": "TYPOGRAPHY" }] }
      ]
    }
  ]
}
```

### `get_screenshot`

The item's screenshot as a PNG image, scaled down so that its longer side is at most 1024 px.

| Argument | Type | Default | Notes |
|---|---|---|---|
| `oid` | integer | — | Required |
| `include_subviews` | boolean | `true` | `false` returns the item alone, without its sublayers and subviews |

Screenshots arrive after the hierarchy, while Supa Lookin syncs them, and **Fast Mode** limits them to expanded items in the same way as attributes. If an item has none yet, the tool returns an error saying so.

### `search`

Items whose class name, title or memory address contains the query, ignoring case and whitespace, the same way as the search field in Supa Lookin's hierarchy panel.

| Argument | Type | Default | Notes |
|---|---|---|---|
| `query` | string | — | Required |
| `limit` | integer | 50 | Between 1 and 500 |

It returns `{"items": [ …item summaries… ], "truncated": false}`.

### `get_selection`

The item selected in the Supa Lookin window, in the same form as `get_item`, or `{"selected": false}` when nothing is selected. This lets you point at something in Supa Lookin and ask the agent about it.

### `reload`

Reloads the hierarchy from the iOS app, the same way as Supa Lookin's Reload menu item, and returns once the new hierarchy has arrived:

```json
{ "reloaded": true, "item_count": 235 }
```

While Supa Lookin is still syncing screenshots and details, `reload` returns an error instead of interrupting the sync. Try again once the sync finishes.

## Errors

A tool that cannot complete returns a result with `isError: true` and a message that says what to do next, for example:

- `No iOS app is being inspected. Pick an app in Supa Lookin first.`
- `No item has oid 424242. The hierarchy may have changed; call get_hierarchy or reload.`
- `The hierarchy is syncing. Try again once Supa Lookin finishes syncing.`

At the HTTP level:

| Status | Cause |
|---|---|
| 401 | Missing or wrong `Authorization` header |
| 403 | The `Origin` header isn't `localhost` or `127.0.0.1` |
| 404 | Unknown or expired MCP session. The MCP specification requires clients to start a new session when they get this. |
| 421 | The `Host` header isn't `localhost` or `127.0.0.1` |

## Security

- The server listens on `127.0.0.1` only and can't be reached from other machines.
- Every request needs the bearer token. Any program running on your Mac can reach a local port, so the token is what keeps other software out.
- Requests whose `Origin` or `Host` header isn't `localhost` or `127.0.0.1` are rejected, which protects against DNS rebinding. Web pages served from localhost pass this check, so the token is what stops them.
- The token is stored in Supa Lookin's preferences (`~/Library/Preferences/icu.retrouvailles.supalookin.plist`). Treat it like a password, and create a new one if it leaks.
- Up to 16 client sessions are kept at a time. When a 17th starts, the oldest is closed.

## Troubleshooting

| Symptom | What to do |
|---|---|
| Preferences shows *Port 47200 is unavailable.* | Another program uses the port. Pick another one with `defaults write icu.retrouvailles.supalookin mcpPort -int <port>`, turn the server off and on, and update your client's URL. |
| The client gets 401 | The token in the client doesn't match. Copy the command from Preferences again. |
| Tools say no app is being inspected | Open Supa Lookin and pick your app. Tools work only while an app is connected and its hierarchy has loaded. |
| The hierarchy looks out of date | Call `reload`. The tools read what Supa Lookin last loaded. |
| `get_screenshot` says there is no screenshot | Wait for Supa Lookin to finish syncing. With Fast Mode on, expand the item in Supa Lookin's hierarchy panel first. Supa Lookin also skips items too large to render, and ones the iOS app opts out of screenshots. |
| `get_item` is missing attributes | Same as above: the item's attributes haven't synced yet. |

## Testing by hand

You can talk to the server with `curl`. Replace `<token>` with your token.

```bash
curl -i http://127.0.0.1:47200/mcp \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"curl","version":"1"}}}'
```

The response carries an `Mcp-Session-Id` header. Send it with every following request, starting with the `notifications/initialized` notification, then `tools/list` or `tools/call`. Responses arrive as server-sent events (`data: {…}` lines).
