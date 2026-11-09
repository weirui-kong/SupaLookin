//
//  SPLKMCPToolHandler.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import SPLKProtocol
import SPLKServer
import MCP

enum SPLKMCPToolHandler {

    static func call(name: String, arguments: [String: Value], agent: String = "local") async -> CallTool.Result {
        do {
            switch name {
            case "wait_for_idle":
                let timeout = TimeInterval(arguments["timeout_ms"].flatMap(integer) ?? 2000) / 1000
                return json(actionResult(try await deviceSession().waitForIdle(timeout: timeout), agent: agent))
            case "take_control":
                let label = arguments["label"]?.stringValue ?? "MCP agent"
                try await deviceSession().arbiter.requestTakeover(session: agent, label: label)
                return json(["controlling": true])
            case "release_control":
                await (try deviceSession()).arbiter.releaseTakeover(session: agent)
                return json(["controlling": false])
            case "tap", "long_press", "set_text", "scroll", "scroll_to_visible", "swipe", "go_back":
                return json(try await performAction(name, arguments: arguments, agent: agent))
            case "tap_at", "type_text":
                return json(try await inject(name, arguments: arguments, agent: agent))
            case "get_status":
                return json(status())
            case "list_apps":
                return json(await listApps())
            case "get_hierarchy":
                let dataSource = try loadedDataSource()
                let roots: [SPLKDisplayItem]
                if let rootOid = arguments["root_oid"].flatMap(integer).flatMap(UInt.init(exactly:)) {
                    roots = [try item(withOid: rootOid, in: dataSource)]
                } else {
                    roots = dataSource.rawHierarchyInfo?.displayItems ?? []
                }
                let maxDepth = arguments["max_depth"].flatMap(integer).map { max($0, 0) }
                let limit = clamp(arguments["limit"].flatMap(integer) ?? 500, to: 1...5000)
                return json(SPLKMCPPayload.hierarchy(roots: roots, maxDepth: maxDepth, limit: limit))
            case "get_item":
                let dataSource = try loadedDataSource()
                return json(SPLKMCPPayload.detail(of: try item(withOid: try requiredOid(arguments), in: dataSource)))
            case "get_screenshot":
                let dataSource = try loadedDataSource()
                let displayItem = try item(withOid: try requiredOid(arguments), in: dataSource)
                let includeSubviews = arguments["include_subviews"]?.boolValue ?? true
                guard let png = SPLKMCPPayload.png(of: displayItem, includeSubviews: includeSubviews) else {
                    return failure("This item has no screenshot yet. It may still be syncing, or the iOS app doesn't capture it.")
                }
                return .init(content: [.image(data: png.base64EncodedString(), mimeType: "image/png", annotations: nil, _meta: nil)], isError: false)
            case "search":
                let dataSource = try loadedDataSource()
                guard let query = arguments["query"]?.stringValue, !query.isEmpty else {
                    return failure("query is required.")
                }
                let limit = clamp(arguments["limit"].flatMap(integer) ?? 50, to: 1...500)
                return json(SPLKMCPPayload.search(query, in: dataSource.flatItems, limit: limit))
            case "get_selection":
                let dataSource = try loadedDataSource()
                guard let selectedItem = dataSource.selectedItem else {
                    return json(["selected": false])
                }
                return json(SPLKMCPPayload.detail(of: selectedItem))
            case "reload":
                return json(try await reload())
            default:
                return failure("Unknown tool \(name).")
            }
        } catch {
            // The recovery suggestion is the part that tells an agent what to do next
            let nsError = SPLKDeviceSession.translate(error) as NSError
            let suggestion = nsError.localizedRecoverySuggestion ?? ""
            return failure(suggestion.isEmpty ? nsError.localizedDescription : "\(nsError.localizedDescription) \(suggestion)")
        }
    }

    // MARK: - Tools

    private static func status() -> [String: Any] {
        let dataSource = SPLKStaticHierarchyDataSource.sharedInstance
        guard let app = SPLKAppsManager.sharedInstance.inspectingApp else {
            return ["inspecting": false, "hint": "Open Supa Lookin and pick an iOS app that has SPLKServer, or call list_apps."]
        }
        var result: [String: Any] = ["inspecting": true, "app": SPLKMCPPayload.appInfo(app.appInfo)]
        result["item_count"] = dataSource.flatItems.count
        if let selectedItem = dataSource.selectedItem {
            result["selected_oid"] = SPLKMCPPayload.oid(of: selectedItem)
        }
        return result
    }

    private static func listApps() async -> [String: Any] {
        let apps = await SPLKAppsManager.sharedInstance.fetchAppInfos(withImage: false, localInfos: nil)
        let inspectingInfo = SPLKAppsManager.sharedInstance.inspectingApp?.appInfo
        let list: [[String: Any]] = apps.map { app in
            var entry: [String: Any] = [:]
            if let appInfo = app.appInfo {
                entry = SPLKMCPPayload.appInfo(appInfo)
                entry["inspecting"] = inspectingInfo?.isEqual(to: appInfo) ?? false
            }
            if let error = app.serverVersionError {
                entry["error"] = error.localizedDescription
            }
            return entry
        }
        return ["apps": list]
    }

    private static func reload() async throws -> [String: Any] {
        guard let windowController = SPLKNavigationManager.sharedInstance.staticWindowController else {
            throw SPLKError.noConnect
        }
        try await windowController.reloadForMCP()
        return ["reloaded": true, "item_count": SPLKStaticHierarchyDataSource.sharedInstance.flatItems.count]
    }

    // MARK: - Control

    private static var lastVersions: [String: UInt64] = [:]

    private static func deviceSession() throws -> SPLKDeviceSession {
        guard let session = SPLKAppsManager.sharedInstance.inspectingApp?.session else {
            throw SPLKError.make("No iOS app is being inspected.", "Pick an app in Supa Lookin first.")
        }
        return session
    }

    // Every write renews this agent's takeover first, so an agent that stops calling loses it.
    private static func controlledSession(agent: String) throws -> SPLKDeviceSession {
        let session = try deviceSession()
        do {
            try session.arbiter.renewTakeover(session: agent)
        } catch {
            throw SPLKError.make(NSLocalizedString("Take over the app before changing it.", comment: ""), "Call take_control first.")
        }
        return session
    }

    private static func performAction(_ name: String, arguments: [String: Value], agent: String) async throws -> [String: Any] {
        let session = try controlledSession(agent: agent)
        var call = SPLKV2PerformAction()
        switch name {
        case "tap": call.action = .tap
        case "long_press": call.action = .longPress
        case "set_text":
            call.action = .setText
            guard let text = arguments["text"]?.stringValue else {
                throw SPLKError.make("text is required.", "")
            }
            call.text = text
        case "scroll": call.action = .scrollBy
        case "scroll_to_visible": call.action = .scrollToVisible
        case "swipe": call.action = .swipe
        default: call.action = .goBack
        }
        if name == "go_back" {
            call.oid = UInt64(arguments["oid"].flatMap(integer).flatMap(UInt.init(exactly:)) ?? 0)
        } else {
            call.oid = UInt64(try requiredOid(arguments))
        }
        call.delta.x = arguments["dx"]?.doubleValue ?? arguments["dx"].flatMap(integer).map(Double.init) ?? 0
        call.delta.y = arguments["dy"]?.doubleValue ?? arguments["dy"].flatMap(integer).map(Double.init) ?? 0
        return actionResult(try await session.performAction(call, as: .mcp(agent)), agent: agent)
    }

    private static func inject(_ name: String, arguments: [String: Value], agent: String) async throws -> [String: Any] {
        let session = try controlledSession(agent: agent)
        var events: [SPLKV2InputEvent] = []
        if name == "tap_at" {
            guard let x = arguments["x"]?.doubleValue ?? arguments["x"].flatMap(integer).map(Double.init),
                  let y = arguments["y"]?.doubleValue ?? arguments["y"].flatMap(integer).map(Double.init),
                  (0...1).contains(x), (0...1).contains(y) else {
                throw SPLKError.make("x and y must be between 0 and 1.", "")
            }
            for phase in [SPLKV2Touch.Phase.began, .ended] {
                var event = SPLKV2InputEvent()
                event.touch.touchID = 950
                event.touch.phase = phase
                event.touch.location.x = x
                event.touch.location.y = y
                events.append(event)
            }
        } else {
            guard let text = arguments["text"]?.stringValue else {
                throw SPLKError.make("text is required.", "")
            }
            var event = SPLKV2InputEvent()
            event.text.text = text
            events.append(event)
        }
        try await session.injectInput(events, as: .mcp(agent))
        return actionResult(try await session.waitForIdle(timeout: 2), agent: agent)
    }

    private static func actionResult(_ result: SPLKV2ActionResult, agent: String) -> [String: Any] {
        var payload: [String: Any] = ["settled": result.settled, "hierarchy_version": result.hierarchyVersion]
        if let last = lastVersions[agent], last != result.hierarchyVersion {
            payload["hint"] = "The UI changed. Call reload before reading items again."
        }
        lastVersions[agent] = result.hierarchyVersion
        return payload
    }

    // MARK: - Helpers

    private static func loadedDataSource() throws -> SPLKStaticHierarchyDataSource {
        let dataSource = SPLKStaticHierarchyDataSource.sharedInstance
        guard SPLKAppsManager.sharedInstance.inspectingApp != nil, dataSource.rawHierarchyInfo != nil else {
            throw SPLKError.make("No iOS app is being inspected.", "Pick an app in Supa Lookin first.")
        }
        return dataSource
    }

    private static func item(withOid oid: UInt, in dataSource: SPLKHierarchyDataSource) throws -> SPLKDisplayItem {
        guard let item = dataSource.displayItem(withOid: oid) else {
            throw SPLKError.make("No item has oid \(oid).", "The hierarchy may have changed; call get_hierarchy or reload.")
        }
        return item
    }

    private static func requiredOid(_ arguments: [String: Value]) throws -> UInt {
        guard let oid = arguments["oid"].flatMap(integer).flatMap(UInt.init(exactly:)) else {
            throw SPLKError.make("oid is required.", "")
        }
        return oid
    }

    // Clients may send any JSON number; Int(_:) would trap on NaN, infinity or an out-of-range double
    static func integer(_ value: Value) -> Int? {
        if let int = value.intValue {
            return int
        }
        guard let double = value.doubleValue, double.isFinite else {
            return nil
        }
        return Int(exactly: double.rounded(.towardZero))
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func json(_ object: Any) -> CallTool.Result {
        guard let data = try? JSONSerialization.data(withJSONObject: SPLKMCPPayload.jsonSafe(object), options: [.sortedKeys, .withoutEscapingSlashes]),
              let text = String(data: data, encoding: .utf8) else {
            return failure("Failed to encode the result.")
        }
        return .init(content: [.text(text: text, annotations: nil, _meta: nil)], isError: false)
    }

    private static func failure(_ message: String) -> CallTool.Result {
        .init(content: [.text(text: message, annotations: nil, _meta: nil)], isError: true)
    }
}
