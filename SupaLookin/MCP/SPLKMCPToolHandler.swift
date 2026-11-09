//
//  SPLKMCPToolHandler.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import SPLKServer
import MCP

enum SPLKMCPToolHandler {

    static func call(name: String, arguments: [String: Value]) async -> CallTool.Result {
        do {
            switch name {
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
            let nsError = error as NSError
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
