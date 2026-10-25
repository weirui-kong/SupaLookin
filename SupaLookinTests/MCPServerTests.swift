//
//  MCPServerTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/10/25.
//

import Cocoa
import Testing
import LookinShared
@testable import SupaLookin

struct MCPPayloadTests {

    private func makeItem(_ className: String, oid: UInt, children: [LookinDisplayItem] = []) -> LookinDisplayItem {
        let layer = LookinObject()
        layer.oid = oid
        layer.classChainList = [className]
        layer.memoryAddress = String(format: "0x%llx", oid)
        let item = LookinDisplayItem()
        item.layerObject = layer
        item.frame = CGRect(x: 1, y: 2, width: 30, height: 40)
        item.alpha = 0.5
        item.subitems = children
        return item
    }

    private func makeTree() -> LookinDisplayItem {
        makeItem("UIWindow", oid: 1, children: [
            makeItem("UILabel", oid: 2),
            makeItem("UIButton", oid: 3, children: [makeItem("UIImageView", oid: 4)]),
        ])
    }

    @Test func hierarchyNodes() throws {
        let result = LKMCPPayload.hierarchy(roots: [makeTree()], maxDepth: nil, limit: 500)
        #expect(result["node_count"] as? Int == 4)
        #expect(result["truncated"] as? Bool == false)

        let window = try #require((result["items"] as? [[String: Any]])?.first)
        #expect(window["oid"] as? UInt == 1)
        #expect(window["class"] as? String == "UIWindow")
        #expect(window["alpha"] as? Double == 0.5)
        #expect((window["frame"] as? [String: Any])?["width"] as? CGFloat == 30)
        let children = try #require(window["children"] as? [[String: Any]])
        #expect(children.map { $0["oid"] as? UInt } == [2, 3])
        #expect(window["children_count"] == nil)
    }

    @Test func hierarchyLimitAndDepth() throws {
        let limited = LKMCPPayload.hierarchy(roots: [makeTree()], maxDepth: nil, limit: 2)
        #expect(limited["node_count"] as? Int == 2)
        #expect(limited["truncated"] as? Bool == true)
        let limitedWindow = try #require((limited["items"] as? [[String: Any]])?.first)
        #expect(limitedWindow["children_count"] as? Int == 2)

        let shallow = LKMCPPayload.hierarchy(roots: [makeTree()], maxDepth: 0, limit: 500)
        let shallowWindow = try #require((shallow["items"] as? [[String: Any]])?.first)
        #expect(shallowWindow["children"] == nil)
        #expect(shallowWindow["children_count"] as? Int == 2)
    }

    @Test func searchMatchesTitlesLikeTheHierarchyPanel() throws {
        let tree = makeTree()
        let flatItems = LookinDisplayItem.flatItems(fromHierarchicalItems: [tree]) ?? []

        let result = LKMCPPayload.search(" label ", in: flatItems, limit: 50)
        let items = try #require(result["items"] as? [[String: Any]])
        #expect(items.map { $0["oid"] as? UInt } == [2])

        let limited = LKMCPPayload.search("UI", in: flatItems, limit: 3)
        #expect((limited["items"] as? [[String: Any]])?.count == 3)
        #expect(limited["truncated"] as? Bool == true)
    }

    @Test func attributeValuesAreJSON() throws {
        let rect = LookinAttribute()
        rect.attrType = .cgRect
        rect.value = NSValue(rect: CGRect(x: 1, y: 2, width: 3, height: 4))
        let rectValue = try #require(LKMCPPayload.value(of: rect) as? [String: Any])
        #expect(rectValue["height"] as? CGFloat == 4)

        let color = LookinAttribute()
        color.attrType = .uiColor
        color.value = [1, 0, 0, 0.5] as [NSNumber]
        #expect(LKMCPPayload.value(of: color) as? String == "(255, 0, 0, 0.50)")

        let enumAttribute = LookinAttribute()
        enumAttribute.attrType = .enumInt
        enumAttribute.identifier = LookinAttr_UILabel_Alignment_Alignment
        enumAttribute.value = NSNumber(value: 1)
        #expect(LKMCPPayload.value(of: enumAttribute) as? String == "NSTextAlignmentCenter")

        #expect(JSONSerialization.isValidJSONObject(["v": LKMCPPayload.value(of: rect)]))
    }
}

@Suite(.serialized)
struct MCPServerTests {

    private static let port = 47299

    private func makeServer() throws -> (LKMCPServer, UserDefaults, String) {
        let suiteName = "SupaLookinTests.mcp.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.set(MCPServerTests.port, forKey: "mcpPort")
        return (LKMCPServer(userDefaults: userDefaults), userDefaults, suiteName)
    }

    private func waitUntilRunning(_ server: LKMCPServer) async throws {
        for _ in 0..<50 {
            if case .running = server.status {
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        Issue.record("The server didn't start: \(server.status)")
    }

    private func post(_ body: String, token: String?, sessionID: String? = nil) async throws -> (Int, String, HTTPURLResponse) {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(MCPServerTests.port)/mcp")!)
        request.httpMethod = "POST"
        request.httpBody = Data(body.utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let sessionID {
            request.setValue(sessionID, forHTTPHeaderField: "Mcp-Session-Id")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try #require(response as? HTTPURLResponse)
        return (httpResponse.statusCode, String(decoding: data, as: UTF8.self), httpResponse)
    }

    @Test func tokenToolsAndSessions() async throws {
        let (server, userDefaults, suiteName) = try makeServer()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        #expect(server.token.count == 64)
        #expect(server.clientCommand.contains("http://127.0.0.1:\(MCPServerTests.port)/mcp"))

        server.start()
        defer { server.stop() }
        try await waitUntilRunning(server)

        let initialize = #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"tests","version":"1"}}}"#

        let (unauthorizedStatus, _, _) = try await post(initialize, token: nil)
        #expect(unauthorizedStatus == 401)
        let (wrongTokenStatus, _, _) = try await post(initialize, token: "nope")
        #expect(wrongTokenStatus == 401)

        let (status, body, response) = try await post(initialize, token: server.token)
        #expect(status == 200)
        #expect(body.contains(#""protocolVersion":"2025-11-25""#))
        let sessionID = try #require(response.value(forHTTPHeaderField: "Mcp-Session-Id"))

        let (initializedStatus, _, _) = try await post(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#, token: server.token, sessionID: sessionID)
        #expect(initializedStatus == 202)

        let (_, tools, _) = try await post(#"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#, token: server.token, sessionID: sessionID)
        for name in ["get_status", "list_apps", "get_hierarchy", "get_item", "get_screenshot", "search", "get_selection", "reload"] {
            #expect(tools.contains(#""name":"\#(name)""#))
        }
        #expect(tools.contains(#""readOnlyHint":true"#))

        let (_, statusResult, _) = try await post(#"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_status","arguments":{}}}"#, token: server.token, sessionID: sessionID)
        #expect(statusResult.contains("inspecting"))
        #expect(statusResult.contains(#""isError":false"#))

        let (unknownSessionStatus, _, _) = try await post(#"{"jsonrpc":"2.0","id":4,"method":"tools/list"}"#, token: server.token, sessionID: "missing")
        #expect(unknownSessionStatus == 404)
    }

    @Test func tokenPersists() throws {
        let (server, userDefaults, suiteName) = try makeServer()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        #expect(LKMCPServer(userDefaults: userDefaults).token == server.token)
        #expect(server.isEnabled)
    }
}

struct MCPPreferencesTests {

    @Test func preferencesWindowBuildsWithTheMCPRow() throws {
        let windowController = LKPreferenceWindowController()
        let view = try #require(windowController.window?.contentView)
        view.layoutSubtreeIfNeeded()
        #expect(view.subviews.contains { ($0 as? NSButton)?.title == NSLocalizedString("Copy Command", comment: "") })
    }
}

struct MCPRobustnessTests {

    @Test func integerArgumentsNeverTrap() {
        #expect(LKMCPToolHandler.integer(.int(7)) == 7)
        #expect(LKMCPToolHandler.integer(.double(3.9)) == 3)
        #expect(LKMCPToolHandler.integer(.double(1e300)) == nil)
        #expect(LKMCPToolHandler.integer(.double(.nan)) == nil)
        #expect(LKMCPToolHandler.integer(.double(-.infinity)) == nil)
        #expect(LKMCPToolHandler.integer(.string("5")) == nil)
    }

    @Test func nonFiniteGeometryStillEncodes() throws {
        let layer = LookinObject()
        layer.oid = 9
        let item = LookinDisplayItem()
        item.layerObject = layer
        item.frame = CGRect(x: CGFloat.nan, y: 0, width: .infinity, height: 1)

        let safe = LKMCPPayload.jsonSafe(LKMCPPayload.hierarchy(roots: [item], maxDepth: nil, limit: 10))
        let data = try JSONSerialization.data(withJSONObject: safe)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(#""x":null"#))
        #expect(text.contains(#""hidden":false"#))
    }
}

@Suite(.serialized)
struct MCPLifecycleTests {

    private static let port = 47298

    private func makeServer() throws -> (LKMCPServer, () -> Void) {
        let suiteName = "SupaLookinTests.mcp.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.set(MCPLifecycleTests.port, forKey: "mcpPort")
        return (LKMCPServer(userDefaults: userDefaults), { userDefaults.removePersistentDomain(forName: suiteName) })
    }

    private func wait(for server: LKMCPServer, _ condition: (LKMCPServerStatus) -> Bool) async throws {
        for _ in 0..<80 {
            if condition(server.status) {
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        Issue.record("Timed out at \(server.status)")
    }

    private func isRunning(_ status: LKMCPServerStatus) -> Bool {
        if case .running = status { return true }
        return false
    }

    @Test func stoppingWhileStartingStaysStopped() async throws {
        let (server, cleanUp) = try makeServer()
        defer { cleanUp() }
        server.start()
        server.stop()
        try await Task.sleep(for: .milliseconds(500))
        #expect(server.status == .stopped)
    }

    @Test func quickOffAndOnRebindsThePort() async throws {
        let (server, cleanUp) = try makeServer()
        defer { cleanUp() }
        server.start()
        try await wait(for: server, isRunning)
        server.stop()
        server.start()
        try await wait(for: server, isRunning)
        server.stop()
    }

    @Test func portConflictFailsAndOffClearsIt() async throws {
        let (first, cleanUpFirst) = try makeServer()
        defer { cleanUpFirst() }
        let (second, cleanUpSecond) = try makeServer()
        defer { cleanUpSecond() }

        first.start()
        try await wait(for: first, isRunning)
        second.start()
        try await wait(for: second) { if case .failed = $0 { return true }; return false }
        #expect(second.status == .failed(String(format: NSLocalizedString("Port %@ is unavailable.", comment: ""), "\(MCPLifecycleTests.port)")))

        second.stop()
        #expect(second.status == .stopped)
        first.stop()
    }

    @Test func reassigningEnabledDoesNothing() throws {
        let (server, cleanUp) = try makeServer()
        defer { cleanUp() }
        server.isEnabled = true
        #expect(server.status == .stopped)
    }
}

struct MCPToolErrorTests {

    @Test func errorsCarryTheirRecoverySuggestion() async {
        // The test host inspects no app
        let result = await LKMCPToolHandler.call(name: "get_item", arguments: ["oid": .int(1)])
        #expect(result.isError == true)
        guard case .text(let text, _, _) = result.content.first else {
            Issue.record("Expected text content")
            return
        }
        #expect(text == "No iOS app is being inspected. Pick an app in Supa Lookin first.")
    }
}
