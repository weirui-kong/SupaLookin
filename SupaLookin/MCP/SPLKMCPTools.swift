//
//  SPLKMCPTools.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/10/25.
//

import Foundation
import MCP

nonisolated enum SPLKMCPTools {

    static func makeServer() async -> Server {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let server = Server(
            name: "Supa Lookin",
            version: version,
            instructions: "Reads and operates the UI of the iOS app that Supa Lookin is inspecting: its view hierarchy, the attributes of each view or layer, and their screenshots. Items are identified by oid. Call get_status first. To change the app (tap, set_text, scroll, ...), call take_control first and release_control when done.",
            capabilities: .init(tools: .init(listChanged: false))
        )
        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: tools)
        }
        // Each MCP session gets its own Server, so this names the agent holding takeover.
        let agent = UUID().uuidString
        await server.withMethodHandler(CallTool.self) { params in
            await SPLKMCPToolHandler.call(name: params.name, arguments: params.arguments ?? [:], agent: agent)
        }
        return server
    }

    static let tools: [Tool] = [
        tool("get_status", "Whether an iOS app is being inspected, which one, how many items its hierarchy has, and which item is selected in the window.", [:]),
        tool("list_apps", "The inspectable iOS apps found right now on simulators and USB devices, marking the one being inspected.", [:]),
        tool("get_hierarchy", "The view and layer tree of the inspected app, from its windows or from root_oid. Each node has oid, class, title, frame (in its superview), hidden, alpha, view_controller and children.", [
            "root_oid": integer("Start from this item instead of the windows."),
            "max_depth": integer("Levels below the root to include. Unlimited by default."),
            "limit": integer("Maximum number of nodes. Defaults to 500."),
        ]),
        tool("get_item", "One item with its frame in the window, bounds, and every attribute the Supa Lookin dashboard shows.", [
            "oid": integer("The item's oid (its view oid works too)."),
        ], required: ["oid"]),
        tool("get_screenshot", "The item's screenshot as a PNG, at most 1024 px on its longer side.", [
            "oid": integer("The item's oid (its view oid works too)."),
            "include_subviews": ["type": "boolean", "description": "Include sublayers and subviews. Defaults to true."],
        ], required: ["oid"]),
        tool("search", "Items whose class name, title or memory address matches the query, like the search field of the hierarchy panel.", [
            "query": ["type": "string", "description": "Text to search for."],
            "limit": integer("Maximum number of results. Defaults to 50."),
        ], required: ["query"]),
        tool("get_selection", "The item selected in the Supa Lookin window, as get_item returns it.", [:]),
        tool("reload", "Reloads the hierarchy from the iOS app, as the Reload menu item does, and returns once it's done.", [:]),
        tool("wait_for_idle", "Waits until the app's UI stops changing and has no running animations. Returns settled and the hierarchy version.", [
            "timeout_ms": integer("How long to wait. Defaults to 2000."),
        ]),
        tool("take_control", "Takes over the app so this agent alone can change it; the Supa Lookin window becomes read-only. Expires 30 s after this agent's last tool call.", [
            "label": ["type": "string", "description": "A name shown to the person at the Mac, such as your client's name."],
        ], readOnly: false),
        tool("release_control", "Gives control of the app back to the Supa Lookin window.", [:], readOnly: false),
        tool("tap", "Taps the item: its accessibility action, its control action, or a synthesized tap at its center. Returns once the UI settles.", [
            "oid": integer("The item's oid (its view oid works too)."),
        ], required: ["oid"], readOnly: false),
        tool("long_press", "Presses and holds the item's center for 0.6 s.", [
            "oid": integer("The item's oid (its view oid works too)."),
        ], required: ["oid"], readOnly: false),
        tool("set_text", "Replaces the text of a text field or text view, as typing would.", [
            "oid": integer("The text field's or text view's oid."),
            "text": ["type": "string", "description": "The new text."],
        ], required: ["oid", "text"], readOnly: false),
        tool("scroll", "Scrolls the item, if it scrolls, or the scroll view around it, by dx and dy points.", [
            "oid": integer("The item's oid."),
            "dx": number("Points to scroll right; negative scrolls left."),
            "dy": number("Points to scroll down; negative scrolls up."),
        ], required: ["oid"], readOnly: false),
        tool("scroll_to_visible", "Scrolls the scroll view around the item until the item is visible.", [
            "oid": integer("The item's oid."),
        ], required: ["oid"], readOnly: false),
        tool("swipe", "Drags one finger from the item's center by dx and dy points.", [
            "oid": integer("The item's oid."),
            "dx": number("Points to move right; negative moves left."),
            "dy": number("Points to move down; negative moves up."),
        ], required: ["oid"], readOnly: false),
        tool("go_back", "Pops the navigation stack the item belongs to, or dismisses its presented screen. Without oid, starts from the key window's root view.", [
            "oid": integer("An item on the screen to go back from."),
        ], readOnly: false),
        tool("tap_at", "Taps a point of the screen, given as fractions of its width and height from the top left.", [
            "x": number("0 is the left edge, 1 the right edge."),
            "y": number("0 is the top edge, 1 the bottom edge."),
        ], required: ["x", "y"], readOnly: false),
        tool("type_text", "Types text into the focused text input.", [
            "text": ["type": "string", "description": "The text to type."],
        ], required: ["text"], readOnly: false),
    ]

    private static func tool(_ name: String, _ description: String, _ properties: [String: Value], required: [String] = [], readOnly: Bool = true) -> Tool {
        var schema: [String: Value] = ["type": "object", "properties": .object(properties)]
        if !required.isEmpty {
            schema["required"] = .array(required.map { .string($0) })
        }
        return Tool(name: name, description: description, inputSchema: .object(schema), annotations: .init(readOnlyHint: readOnly, openWorldHint: false))
    }

    private static func integer(_ description: String) -> Value {
        ["type": "integer", "description": .string(description)]
    }

    private static func number(_ description: String) -> Value {
        ["type": "number", "description": .string(description)]
    }
}
