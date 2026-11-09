//
//  MCPWriteToolsTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import Testing
import MCP
@testable import SupaLookin

struct MCPWriteToolsTests {

    @Test func writeToolsAreMarkedAsWriting() {
        let writeTools: Set<String> = ["take_control", "release_control", "tap", "long_press", "set_text", "scroll", "scroll_to_visible", "swipe", "go_back", "tap_at", "type_text"]
        let tools = Dictionary(uniqueKeysWithValues: SPLKMCPTools.tools.map { ($0.name, $0) })
        for name in writeTools {
            #expect(tools[name]?.annotations.readOnlyHint == false, "\(name)")
        }
        #expect(tools["wait_for_idle"]?.annotations.readOnlyHint == true)
        #expect(tools["get_item"]?.annotations.readOnlyHint == true)
    }

    @Test func writingWithoutAnAppFails() async {
        let result = await SPLKMCPToolHandler.call(name: "tap", arguments: ["oid": .int(1)], agent: "test")
        #expect(result.isError == true)
    }
}
