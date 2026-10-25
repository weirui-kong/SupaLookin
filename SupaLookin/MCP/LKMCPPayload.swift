//
//  LKMCPPayload.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

enum LKMCPPayload {

    static let screenshotMaxLength: CGFloat = 1024

    static func oid(of item: LookinDisplayItem) -> UInt {
        item.layerObject?.oid ?? item.viewObject?.oid ?? 0
    }

    static func appInfo(_ appInfo: LookinAppInfo?) -> [String: Any] {
        guard let appInfo else {
            return [:]
        }
        var result: [String: Any] = [:]
        result["name"] = appInfo.appName
        result["bundle_id"] = appInfo.appBundleIdentifier
        result["device"] = appInfo.deviceDescription
        result["os"] = appInfo.osDescription
        result["server_version"] = appInfo.serverReadableVersion as String?
        return result
    }

    static func summary(of item: LookinDisplayItem) -> [String: Any] {
        var result: [String: Any] = ["oid": oid(of: item)]
        if let viewOid = item.viewObject?.oid {
            result["view_oid"] = viewOid
        }
        if let className = item.displayingObject()?.completedDemangledClassName {
            result["class"] = className
        }
        result["title"] = item.title
        result["frame"] = rect(item.frame)
        result["hidden"] = item.isHidden
        result["alpha"] = Double(item.alpha)
        if let viewController = item.hostViewControllerObject?.completedDemangledClassName {
            result["view_controller"] = viewController
        }
        return result
    }

    static func hierarchy(roots: [LookinDisplayItem], maxDepth: Int?, limit: Int) -> [String: Any] {
        var count = 0
        var truncated = false

        func node(_ item: LookinDisplayItem, depth: Int) -> [String: Any]? {
            guard count < limit else {
                truncated = true
                return nil
            }
            count += 1
            var result = summary(of: item)
            let subitems = item.subitems ?? []
            if let maxDepth, depth >= maxDepth {
                if !subitems.isEmpty {
                    result["children_count"] = subitems.count
                }
                return result
            }
            let children = subitems.compactMap { node($0, depth: depth + 1) }
            if !children.isEmpty {
                result["children"] = children
            }
            if children.count < subitems.count {
                result["children_count"] = subitems.count
            }
            return result
        }

        let nodes = roots.compactMap { node($0, depth: 0) }
        return ["items": nodes, "node_count": count, "truncated": truncated]
    }

    static func detail(of item: LookinDisplayItem) -> [String: Any] {
        var result = summary(of: item)
        result["frame_in_window"] = rect(item.calculateFrameToRoot())
        result["bounds"] = rect(item.bounds)
        result["children_count"] = item.subitems?.count ?? 0
        result["attribute_groups"] = (item.queryAllAttrGroupList() ?? []).map(group)
        return result
    }

    static func search(_ query: String, in items: [LookinDisplayItem], limit: Int) -> [String: Any] {
        // Same normalization as the hierarchy panel's search field
        let searchString = query.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
        guard !searchString.isEmpty else {
            return ["items": [], "truncated": false]
        }
        let matches = items.filter { $0.isMatched(withSearchString: searchString) }
        return ["items": matches.prefix(limit).map(summary), "truncated": matches.count > limit]
    }

    static func png(of item: LookinDisplayItem, includeSubviews: Bool) -> Data? {
        guard let image = includeSubviews ? item.groupScreenshot : item.soloScreenshot,
              image.size.width > 0, image.size.height > 0,
              let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let scale = min(1, screenshotMaxLength / CGFloat(max(source.width, source.height)))
        let width = max(1, Int(CGFloat(source.width) * scale))
        let height = max(1, Int(CGFloat(source.height) * scale))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let scaled = context.makeImage() else {
            return nil
        }
        return NSBitmapImageRep(cgImage: scaled).representation(using: .png, properties: [:])
    }

    // MARK: - Attributes

    private static func group(_ group: LookinAttributesGroup) -> [String: Any] {
        let groupTitle = group.queryDisplayTitle()
        return ["title": groupTitle, "sections": (group.attrSections ?? []).map { section($0, groupTitle: groupTitle) }]
    }

    private static func section(_ section: LookinAttributesSection, groupTitle: String) -> [String: Any] {
        let sectionTitle = section.isUserCustom() ? nil : LookinDashboardBlueprint.sectionTitle(withSectionID: section.identifier)
        var result: [String: Any] = ["attributes": (section.attributes ?? []).map { attribute($0, fallbackTitle: sectionTitle ?? groupTitle) }]
        if let sectionTitle {
            result["title"] = sectionTitle
        }
        return result
    }

    // The dashboard draws some attributes, such as the class chain or the constraint list, without a title of their own
    private static func attribute(_ attribute: LookinAttribute, fallbackTitle: String) -> [String: Any] {
        let title = attribute.isUserCustom() ? attribute.displayTitle : LookinDashboardBlueprint.fullTitle(withAttrID: attribute.identifier)
        return ["title": title ?? fallbackTitle, "value": value(of: attribute)]
    }

    static func value(of attribute: LookinAttribute) -> Any {
        let value = attribute.value
        switch attribute.attrType {
        case .BOOL:
            return (value as? NSNumber)?.boolValue ?? NSNull()
        case .cgPoint:
            guard let point = (value as? NSValue)?.pointValue else { return NSNull() }
            return ["x": point.x, "y": point.y]
        case .cgSize:
            guard let size = (value as? NSValue)?.sizeValue else { return NSNull() }
            return ["width": size.width, "height": size.height]
        case .cgRect:
            guard let rect = (value as? NSValue)?.rectValue else { return NSNull() }
            return self.rect(rect)
        case .uiEdgeInsets:
            guard let insets = (value as? NSValue)?.edgeInsetsValue else { return NSNull() }
            return ["top": insets.top, "left": insets.left, "bottom": insets.bottom, "right": insets.right]
        case .uiColor:
            return color(value)
        case .enumInt, .enumLong:
            guard let number = value as? NSNumber else { return NSNull() }
            let enumListName = LookinDashboardBlueprint.enumListName(withAttrID: attribute.identifier) ?? ""
            return LKEnumListRegistry.sharedInstance.desc(forEnumName: enumListName, value: number.intValue) ?? number
        case .shadow:
            guard let info = value as? [String: Any] else { return NSNull() }
            var shadow: [String: Any] = ["color": color(info["color"])]
            if let offset = (info["offset"] as? NSValue)?.sizeValue {
                shadow["offset"] = ["width": offset.width, "height": offset.height]
            }
            shadow["opacity"] = info["opacity"] as? NSNumber ?? NSNull()
            shadow["radius"] = info["radius"] as? NSNumber ?? NSNull()
            return shadow
        case .customObj:
            if attribute.identifier == LookinAttr_Class_Class_Class {
                // Demangled the way the Class card shows it
                return (value as? [[String]] ?? []).map { $0.map { LKSwiftDemangler.completedParse(input: $0) } }
            }
            if attribute.identifier == LookinAttr_AutoLayout_Constraints_Constraints {
                return (value as? [LookinAutoLayoutConstraint] ?? []).map { constraint in
                    ["constraint": constraint.summaryText, "effective": constraint.effective] as [String: Any]
                }
            }
            return jsonCompatible(value)
        default:
            return jsonCompatible(value)
        }
    }

    private static func color(_ components: Any?) -> Any {
        guard let color = NSColor.color(fromRGBAComponents: components as? [Any]) else {
            return NSNull()
        }
        return color.rgbaString
    }

    private static func jsonCompatible(_ value: Any?) -> Any {
        guard let value else {
            return NSNull()
        }
        if JSONSerialization.isValidJSONObject([value]) {
            return value
        }
        return String(describing: value)
    }

    // A device can report NaN or infinite geometry, which JSONSerialization refuses for the whole document
    static func jsonSafe(_ object: Any) -> Any {
        switch object {
        case let dictionary as [String: Any]:
            return dictionary.mapValues(jsonSafe)
        case let array as [Any]:
            return array.map(jsonSafe)
        case let number as NSNumber:
            return number.doubleValue.isFinite ? number : NSNull()
        default:
            return object
        }
    }

    private static func rect(_ rect: CGRect) -> [String: Any] {
        ["x": rect.origin.x, "y": rect.origin.y, "width": rect.size.width, "height": rect.size.height]
    }
}
