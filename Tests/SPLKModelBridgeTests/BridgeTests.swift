//
//  BridgeTests.swift
//  SPLKModelBridgeTests
//
//  Created by Weirui Kong on 2026/11/10.
//

import AppKit
import Testing
import SPLKProtocol
import SPLKServer
@testable import SPLKModelBridge

private func color(_ r: Float, _ g: Float, _ b: Float, _ a: Float) -> SPLKV2Color {
    var color = SPLKV2Color()
    (color.r, color.g, color.b, color.a) = (r, g, b, a)
    return color
}

private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> SPLKV2Rect {
    SPLKBridge.rect(CGRect(x: x, y: y, width: w, height: h))
}

private func objectRef(_ oid: UInt64) -> SPLKV2ObjectRef {
    var object = SPLKV2ObjectRef()
    object.oid = oid
    object.memoryAddress = "0x\(oid)"
    object.classChain = ["UILabel", "UIView", "UIResponder", "NSObject"]
    object.specialTrace = "special"
    var trace = SPLKV2IvarTrace()
    trace.relation = "superview"
    trace.hostClassName = "Host"
    trace.ivarName = "_label"
    object.ivarTraces = [trace]
    return object
}

private func attribute(_ identifier: String, _ type: SPLKV2AttrType, _ value: SPLKV2Value?) -> SPLKV2Attribute {
    var attribute = SPLKV2Attribute()
    attribute.identifier = identifier
    attribute.type = type
    if let value {
        attribute.value = value
    }
    return attribute
}

private func value(_ build: (inout SPLKV2Value) -> Void) -> SPLKV2Value {
    var value = SPLKV2Value()
    build(&value)
    return value
}

struct AttributeValueTests {

    // One row per line of the M2 spec's attribute value table.
    static let rows: [(SPLKAttrType, String?, SPLKV2Value)] = [
        (.int, nil, value { $0.intValue = -7 }),
        (.enumLong, nil, value { $0.intValue = 3 }),
        (.unsignedLongLong, nil, value { $0.uintValue = 9 }),
        (.double, nil, value { $0.doubleValue = 0.25 }),
        (.BOOL, nil, value { $0.boolValue = true }),
        (.nsString, nil, value { $0.stringValue = "text" }),
        (.json, nil, value { $0.stringValue = "{\"a\":1}" }),
        (.cgPoint, nil, value { $0.point = SPLKBridge.point(CGPoint(x: 1, y: 2)) }),
        (.cgVector, nil, value { $0.point = SPLKBridge.point(CGPoint(x: 3, y: 4)) }),
        (.uiOffset, nil, value { $0.point = SPLKBridge.point(CGPoint(x: 5, y: 6)) }),
        (.cgSize, nil, value { $0.size = SPLKBridge.size(CGSize(width: 7, height: 8)) }),
        (.cgRect, nil, value { $0.rect = rect(1, 2, 3, 4) }),
        (.cgAffineTransform, nil, value {
            var transform = SPLKV2AffineTransform()
            (transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty) = (1, 0, 0, 2, 5, 6)
            $0.transform = transform
        }),
        (.uiEdgeInsets, nil, value { $0.insets = SPLKBridge.insets(top: 1, left: 2, bottom: 3, right: 4) }),
        (.uiColor, nil, value { $0.color = color(1, 0.5, 0.25, 1) }),
        (.shadow, nil, value {
            var shadow = SPLKV2Shadow()
            shadow.color = color(0, 0, 0, 0.5)
            shadow.offset = SPLKBridge.size(CGSize(width: 0, height: 2))
            shadow.opacity = 0.3
            shadow.radius = 4
            $0.shadow = shadow
        }),
        (.customObj, SPLKAttr_Class_Class_Class, value {
            $0.list.values = [["UILabel", "UIView"], ["NSObject"]].map { strings in
                value { $0.list.values = strings.map { string in value { $0.stringValue = string } } }
            }
        }),
        (.customObj, SPLKAttr_Relation_Relation_Relation, value { $0.list.values = [value { $0.stringValue = "superview" }] }),
        (.customObj, SPLKAttr_AutoLayout_Constraints_Constraints, value {
            var constraint = SPLKV2Constraint()
            constraint.effective = true
            constraint.active = true
            constraint.firstItem = objectRef(1)
            constraint.firstItemType = .itemSelf
            constraint.firstAttribute = 7
            constraint.relation = 1
            constraint.secondItemType = .itemNil
            constraint.multiplier = 1
            constraint.constant = 44
            constraint.priority = 1000
            constraint.identifier = "height"
            $0.list.values = [value { $0.constraint = constraint }]
        }),
        (.customObj, SPLKAttr_UIVisualEffectView_Style_Style, value { $0.intValue = 2 }),
        (.customObj, SPLKAttr_UIImageView_Open_Open, value { $0.uintValue = 99 }),
        (.customObj, SPLKAttr_UITableView_RowsNumber_Number, value { $0.list.values = [value { $0.intValue = 3 }, value { $0.intValue = 0 }] }),
        (.nsString, nil, value { $0.nullValue = SPLKV2Empty() }),
    ]

    @Test(arguments: rows.indices)
    func roundTrips(_ index: Int) throws {
        let (type, identifier, message) = Self.rows[index]
        let object = SPLKBridge.objectValue(message, type: type, identifier: identifier)
        let back = SPLKBridge.valueMessage(object, type: type, identifier: identifier)
        #expect(back == message)
    }

    @Test func objectiveCShapes() {
        let rows = Self.rows
        #expect(SPLKBridge.objectValue(rows[11].2, type: .cgRect, identifier: nil) as? NSValue == NSValue(rect: CGRect(x: 1, y: 2, width: 3, height: 4)))
        #expect(SPLKBridge.objectValue(rows[14].2, type: .uiColor, identifier: nil) as? [NSNumber] == [1, 0.5, 0.25, 1])
        #expect(SPLKBridge.objectValue(rows[16].2, type: .customObj, identifier: SPLKAttr_Class_Class_Class) as? [[String]] == [["UILabel", "UIView"], ["NSObject"]])
        let constraints = SPLKBridge.objectValue(rows[18].2, type: .customObj, identifier: SPLKAttr_AutoLayout_Constraints_Constraints) as? [SPLKAutoLayoutConstraint]
        #expect(constraints?.first?.constant == 44)
        #expect(constraints?.first?.firstItem?.oid == 1)
        let shadow = SPLKBridge.objectValue(rows[15].2, type: .shadow, identifier: nil) as? [String: Any]
        #expect((shadow?["offset"] as? NSValue)?.sizeValue == CGSize(width: 0, height: 2))
        #expect(SPLKBridge.objectValue(rows[22].2, type: .nsString, identifier: nil) == nil)
    }

    @Test func voidHasNoValue() {
        #expect(SPLKBridge.valueMessage(nil, type: .void, identifier: nil) == nil)
    }
}

struct ModelRoundTripTests {

    private func richNode(depth: UInt32, oid: UInt64) -> SPLKV2Node {
        var node = SPLKV2Node()
        node.depth = depth
        node.view = objectRef(oid)
        node.layer = objectRef(oid + 1)
        node.hostViewController = objectRef(oid + 2)
        node.frame = rect(1, 2, 30, 40)
        node.bounds = rect(0, 0, 30, 40)
        node.hidden = true
        node.alpha = 0.5
        node.backgroundColor = color(0, 0, 1, 1)
        node.representedAsKeyWindow = depth == 0
        node.shouldCaptureImage = true
        node.customDisplayTitle = "Custom"
        node.danceuiSource = "src"
        var info = SPLKV2CustomNodeInfo()
        info.frameInWindow = rect(5, 6, 7, 8)
        info.title = "t"
        info.subtitle = "s"
        node.customInfo = info
        var group = SPLKV2AttributeGroup()
        group.identifier = "g"
        group.customTitle = "Group"
        var section = SPLKV2AttributeSection()
        section.identifier = "s"
        var enumAttribute = attribute("e", .attrEnumString, value { $0.stringValue = "b" })
        enumAttribute.enumCases = ["a", "b"]
        enumAttribute.customSetterID = "setter"
        section.attributes = [attribute("x", .attrCgRect, value { $0.rect = rect(1, 1, 2, 2) }), enumAttribute]
        group.sections = [section]
        node.attributeGroups = [group]
        node.customAttributeGroups = [group]
        var handler = SPLKV2EventHandler()
        handler.kind = .gesture
        handler.eventName = "Tap"
        var pair = SPLKV2StringPair()
        pair.first = "target"
        pair.second = "action:"
        handler.targetActions = [pair]
        handler.inheritedRecognizerName = "UITapGestureRecognizer"
        handler.gestureEnabled = true
        handler.gestureDelegator = "Delegate"
        handler.recognizerIvarTraces = ["_tap"]
        handler.recognizerOid = 77
        node.eventHandlers = [handler]
        return node
    }

    @Test func hierarchySnapshot() {
        var snapshot = SPLKV2HierarchySnapshot()
        snapshot.version = 3
        snapshot.nodes = [richNode(depth: 0, oid: 10), richNode(depth: 1, oid: 20), richNode(depth: 2, oid: 30), richNode(depth: 1, oid: 40), richNode(depth: 0, oid: 50)]
        var group = SPLKV2ColorAliasGroup()
        var nested = SPLKV2ColorAlias()
        nested.color = color(1, 1, 1, 1)
        group.entries = ["white": nested]
        var alias = SPLKV2ColorAlias()
        alias.group = group
        var red = SPLKV2ColorAlias()
        red.color = color(1, 0, 0, 1)
        snapshot.colorAlias = ["Brand": alias, "red": red]
        snapshot.collapsedClassList = ["UIButton"]
        snapshot.app = SPLKBridge.summary(SPLKBridge.appInfo(appSummary()), screen: nil)

        let info = SPLKBridge.hierarchyInfo(snapshot)
        #expect(info.displayItems.count == 2)
        #expect(info.displayItems[0].subitems.count == 2)
        #expect(info.displayItems[0].subitems[0].`super` === info.displayItems[0])
        #expect(SPLKBridge.snapshot(info, version: 3, screen: snapshot.app.screen) == snapshot)
    }

    private func appSummary() -> SPLKV2AppSummary {
        var summary = SPLKV2AppSummary()
        summary.identifier = 12
        summary.name = "Demo"
        summary.bundleIdentifier = "icu.demo"
        summary.deviceDescription = "iPhone"
        summary.osDescription = "27.1"
        summary.osMainVersion = 27
        summary.deviceType = .simulator
        var screen = SPLKV2ScreenInfo()
        screen.size = SPLKBridge.size(CGSize(width: 402, height: 874))
        screen.scale = 3
        summary.screen = screen
        return summary
    }

    @Test func appInfo() {
        var message = SPLKV2AppInfo()
        message.summary = appSummary()
        message.shouldUseCache = true
        let info = SPLKBridge.appInfo(message)
        #expect(info.deviceType == .simulator)
        #expect(SPLKBridge.appInfoMessage(info, screen: nil) == message)
    }

    @Test func nodeDetailKeepsUnsetDistinct() {
        var detail = SPLKV2NodeDetail()
        detail.oid = 5
        detail.hidden = false
        detail.customDisplayTitle = ""
        detail.failureCode = -1
        let model = SPLKBridge.detail(detail)
        #expect(model.hiddenValue == false)
        #expect(model.alphaValue == nil)
        #expect(model.frameValue == nil)
        #expect(model.customDisplayTitle == "")
        #expect(model.subitems == nil)
        #expect(SPLKBridge.detailMessage(model) == detail)

        detail.frame = rect(1, 2, 3, 4)
        detail.alpha = 1
        detail.childrenSet = true
        detail.children = [richNode(depth: 0, oid: 1), richNode(depth: 1, oid: 2)]
        #expect(SPLKBridge.detailMessage(SPLKBridge.detail(detail)) == detail)

        detail.children = []
        #expect(SPLKBridge.detail(detail).subitems?.isEmpty == true)
    }

    @Test func screenshotsTravelAsPNG() throws {
        let image = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        let model = SPLKDisplayItemDetail()
        model.displayItemOid = 1
        model.soloScreenshot = image
        let message = SPLKBridge.detailMessage(model)
        #expect(message.soloScreenshot.format == .png)
        #expect(message.soloScreenshot.data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(SPLKBridge.detail(message).soloScreenshot != nil)
    }

    @Test func tasksAndModifications() {
        var task = SPLKV2DetailTask()
        task.oid = 9
        task.screenshot = .group
        task.attrRequest = .attrNeed
        task.needBasicVisualInfo = true
        task.needSubitems = true
        task.frameSize = SPLKBridge.size(CGSize(width: 10, height: 20))
        var package = SPLKV2DetailTaskPackage()
        package.tasks = [task]
        let model = SPLKBridge.package(package, clientVersion: "2.0")
        #expect(model.tasks.first?.clientReadableVersion == "2.0")
        #expect(SPLKBridge.packageMessage(model) == package)

        var modification = SPLKV2ModifyAttribute()
        modification.targetOid = 3
        modification.setter = "setAlpha:"
        modification.getter = "alpha"
        modification.type = .attrFloat
        modification.value = value { $0.doubleValue = 0.5 }
        #expect(SPLKBridge.modificationMessage(SPLKBridge.modification(modification, clientVersion: "2.0")) == modification)

        var custom = SPLKV2ModifyCustomAttribute()
        custom.customSetterID = "id"
        custom.type = .attrUiColor
        custom.value = value { $0.color = color(0, 1, 0, 1) }
        #expect(SPLKBridge.customModificationMessage(SPLKBridge.customModification(custom)) == custom)
    }

    @Test func objectAndGroups() {
        #expect(SPLKBridge.objectRef(SPLKBridge.object(objectRef(4))) == objectRef(4))
        let group = richNode(depth: 0, oid: 1).attributeGroups[0]
        #expect(SPLKBridge.groupMessage(SPLKBridge.group(group)) == group)
    }

    // Releasing a deep Objective-C graph recurses, and test tasks run on small stacks.
    @Test func deepHierarchiesFlattenAndRebuild() {
        let nodes = (0..<300).map { richNode(depth: UInt32($0), oid: UInt64($0)) }
        let roots = SPLKBridge.rebuild(nodes)
        #expect(roots.count == 1)
        var item: SPLKDisplayItem? = roots[0]
        var depth = 0
        while let current = item, let child = current.subitems?.first {
            #expect(child.`super` === current)
            item = child
            depth += 1
        }
        #expect(depth == 299)
        #expect(SPLKBridge.flatten(roots) == nodes)
    }
}

struct ErrorMappingTests {

    @Test func objectiveCErrorsBecomeStatuses() {
        let notFound = NSError(domain: SPLKErrorDomain, code: Int(SPLKErrCode_ObjectNotFound), userInfo: [NSLocalizedDescriptionKey: "Gone", NSLocalizedRecoverySuggestionErrorKey: "Reload"])
        #expect(SPLKBridge.statusError(notFound) == SPLKStatusError(.notFound, reason: "object_deallocated", title: "Gone", detail: "Reload"))
        let other = NSError(domain: SPLKErrorDomain, code: Int(SPLKErrCode_Default), userInfo: [NSLocalizedDescriptionKey: "No method"])
        #expect(SPLKBridge.statusError(other) == SPLKStatusError(.internal, reason: "error", title: "No method"))
        #expect(SPLKBridge.statusError(NSError(domain: SPLKErrorDomain, code: Int(SPLKErrCode_Inner))).reason == "inner")
    }
}
