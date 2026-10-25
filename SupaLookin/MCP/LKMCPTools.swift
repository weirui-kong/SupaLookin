//
//  LKMCPTools.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/10/25.
//

import Foundation
import MCP

nonisolated enum LKMCPTools {

    static func makeServer() async -> Server {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let server = Server(
            name: "Supa Lookin",
            version: version,
            instructions: "Reads the UI of the iOS app that Supa Lookin is inspecting: its view hierarchy, the attributes of each view or layer, and their screenshots. Items are identified by oid. Call get_status first.",
            capabilities: .init(tools: .init(listChanged: false))
        )
        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: tools)
        }
        await server.withMethodHandler(CallTool.self) { params in
            await LKMCPToolHandler.call(name: params.name, arguments: params.arguments ?? [:])
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
    ]

    private static func tool(_ name: String, _ description: String, _ properties: [String: Value], required: [String] = []) -> Tool {
        var schema: [String: Value] = ["type": "object", "properties": .object(properties)]
        if !required.isEmpty {
            schema["required"] = .array(required.map { .string($0) })
        }
        return Tool(name: name, description: description, inputSchema: .object(schema), annotations: .init(readOnlyHint: true, openWorldHint: false))
    }

    private static func integer(_ description: String) -> Value {
        ["type": "integer", "description": .string(description)]
    }
}
