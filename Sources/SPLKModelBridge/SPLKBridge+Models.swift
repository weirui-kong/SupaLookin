//
//  SPLKBridge+Models.swift
//  SPLKModelBridge
//
//  Created by Weirui Kong on 2026/11/10.
//

#if SHOULD_COMPILE_SPLK_SHARED

import Foundation
import CoreGraphics
import SPLKProtocol
import SPLKServer

extension SPLKBridge {

    // MARK: - Objects

    public static func objectRef(_ object: SPLKObject) -> SPLKV2ObjectRef {
        var message = SPLKV2ObjectRef()
        message.oid = UInt64(object.oid)
        message.memoryAddress = object.memoryAddress ?? ""
        message.classChain = object.classChainList ?? []
        message.specialTrace = object.specialTrace ?? ""
        message.ivarTraces = (object.ivarTraces ?? []).map { trace in
            var traceMessage = SPLKV2IvarTrace()
            traceMessage.relation = trace.relation ?? ""
            traceMessage.hostClassName = trace.hostClassName ?? ""
            traceMessage.ivarName = trace.ivarName ?? ""
            return traceMessage
        }
        return message
    }

    public static func object(_ message: SPLKV2ObjectRef) -> SPLKObject {
        let object = SPLKObject()
        object.oid = UInt(message.oid)
        object.memoryAddress = message.memoryAddress
        object.classChainList = message.classChain
        object.specialTrace = message.specialTrace.isEmpty ? nil : message.specialTrace
        object.ivarTraces = message.ivarTraces.map { traceMessage in
            let trace = SPLKIvarTrace()
            trace.relation = traceMessage.relation.isEmpty ? nil : traceMessage.relation
            trace.hostClassName = traceMessage.hostClassName
            trace.ivarName = traceMessage.ivarName
            return trace
        }
        return object
    }

    // MARK: - Event handlers and custom info

    static func eventHandlerMessage(_ handler: SPLKEventHandler) -> SPLKV2EventHandler {
        var message = SPLKV2EventHandler()
        message.kind = SPLKV2EventHandler.Kind(rawValue: handler.handlerType.rawValue + 1) ?? .unspecified
        message.eventName = handler.eventName ?? ""
        message.targetActions = (handler.targetActions ?? []).map { tuple in
            var pair = SPLKV2StringPair()
            pair.first = tuple.first ?? ""
            pair.second = tuple.second ?? ""
            return pair
        }
        message.inheritedRecognizerName = handler.inheritedRecognizerName ?? ""
        message.gestureEnabled = handler.gestureRecognizerIsEnabled
        message.gestureDelegator = handler.gestureRecognizerDelegator ?? ""
        message.recognizerIvarTraces = handler.recognizerIvarTraces ?? []
        message.recognizerOid = handler.recognizerOid
        return message
    }

    static func eventHandler(_ message: SPLKV2EventHandler) -> SPLKEventHandler {
        let handler = SPLKEventHandler()
        handler.handlerType = SPLKEventHandlerType(rawValue: max(message.kind.rawValue - 1, 0)) ?? .targetAction
        handler.eventName = message.eventName
        handler.targetActions = message.targetActions.map { SPLKStringTwoTuple(first: $0.first, second: $0.second) }
        handler.inheritedRecognizerName = message.inheritedRecognizerName.isEmpty ? nil : message.inheritedRecognizerName
        handler.gestureRecognizerIsEnabled = message.gestureEnabled
        handler.gestureRecognizerDelegator = message.gestureDelegator.isEmpty ? nil : message.gestureDelegator
        handler.recognizerIvarTraces = message.recognizerIvarTraces
        handler.recognizerOid = message.recognizerOid
        return handler
    }

    static func customInfoMessage(_ info: SPLKCustomDisplayItemInfo) -> SPLKV2CustomNodeInfo {
        var message = SPLKV2CustomNodeInfo()
        if let frame = rectValue(info.frameInWindow) {
            message.frameInWindow = rect(frame)
        }
        message.title = info.title ?? ""
        message.subtitle = info.subtitle ?? ""
        message.danceuiSource = info.danceuiSource ?? ""
        return message
    }

    static func customInfo(_ message: SPLKV2CustomNodeInfo) -> SPLKCustomDisplayItemInfo {
        let info = SPLKCustomDisplayItemInfo()
        info.frameInWindow = message.hasFrameInWindow ? makeValue(rect: cgRect(message.frameInWindow)) : nil
        info.title = message.title.isEmpty ? nil : message.title
        info.subtitle = message.subtitle.isEmpty ? nil : message.subtitle
        info.danceuiSource = message.danceuiSource.isEmpty ? nil : message.danceuiSource
        return info
    }

    // MARK: - Attributes

    public static func groupMessage(_ group: SPLKAttributesGroup) -> SPLKV2AttributeGroup {
        var message = SPLKV2AttributeGroup()
        message.identifier = group.identifier ?? ""
        message.customTitle = group.userCustomTitle ?? ""
        message.sections = (group.attrSections ?? []).map { section in
            var sectionMessage = SPLKV2AttributeSection()
            sectionMessage.identifier = section.identifier ?? ""
            sectionMessage.attributes = (section.attributes ?? []).map(attributeMessage)
            return sectionMessage
        }
        return message
    }

    public static func group(_ message: SPLKV2AttributeGroup) -> SPLKAttributesGroup {
        let group = SPLKAttributesGroup()
        group.identifier = message.identifier
        group.userCustomTitle = message.customTitle.isEmpty ? nil : message.customTitle
        group.attrSections = message.sections.map { sectionMessage in
            let section = SPLKAttributesSection()
            section.identifier = sectionMessage.identifier
            section.attributes = sectionMessage.attributes.map(attribute)
            return section
        }
        return group
    }

    static func attributeMessage(_ attribute: SPLKAttribute) -> SPLKV2Attribute {
        var message = SPLKV2Attribute()
        message.identifier = attribute.identifier ?? ""
        message.displayTitle = attribute.displayTitle ?? ""
        message.type = SPLKV2AttrType(rawValue: attribute.attrType.rawValue) ?? .attrNone
        if let value = valueMessage(attribute.value, type: attribute.attrType, identifier: attribute.identifier) {
            message.value = value
        }
        if attribute.attrType == .enumString, let cases = attribute.extraValue as? [String] {
            message.enumCases = cases
        }
        message.customSetterID = attribute.customSetterID ?? ""
        return message
    }

    static func attribute(_ message: SPLKV2Attribute) -> SPLKAttribute {
        let attribute = SPLKAttribute()
        attribute.identifier = message.identifier
        attribute.displayTitle = message.displayTitle.isEmpty ? nil : message.displayTitle
        attribute.attrType = SPLKAttrType(rawValue: message.type.rawValue) ?? .none
        attribute.value = objectValue(message.hasValue ? message.value : nil, type: attribute.attrType, identifier: message.identifier)
        if attribute.attrType == .enumString {
            attribute.extraValue = message.enumCases
        }
        attribute.customSetterID = message.customSetterID.isEmpty ? nil : message.customSetterID
        return attribute
    }

    // MARK: - Nodes

    static func nodeMessage(_ item: SPLKDisplayItem, depth: UInt32) -> SPLKV2Node {
        var message = SPLKV2Node()
        message.depth = depth
        if let object = item.viewObject {
            message.view = objectRef(object)
        }
        if let object = item.layerObject {
            message.layer = objectRef(object)
        }
        if let object = item.hostViewControllerObject {
            message.hostViewController = objectRef(object)
        }
        message.frame = rect(item.frame)
        message.bounds = rect(item.bounds)
        message.hidden = item.isHidden
        message.alpha = item.alpha
        if let background = item.backgroundColor, let colorMessage = color(background) {
            message.backgroundColor = colorMessage
        }
        message.representedAsKeyWindow = item.representedAsKeyWindow
        message.shouldCaptureImage = item.shouldCaptureImage
        message.customDisplayTitle = item.customDisplayTitle ?? ""
        message.danceuiSource = item.danceuiSource ?? ""
        if let info = item.customInfo {
            message.customInfo = customInfoMessage(info)
        }
        message.attributeGroups = (item.attributesGroupList ?? []).map(groupMessage)
        message.customAttributeGroups = (item.customAttrGroupList ?? []).map(groupMessage)
        message.eventHandlers = (item.eventHandlers ?? []).map(eventHandlerMessage)
        return message
    }

    static func displayItem(_ message: SPLKV2Node) -> SPLKDisplayItem {
        let item = SPLKDisplayItem()
        item.viewObject = message.hasView ? object(message.view) : nil
        item.layerObject = message.hasLayer ? object(message.layer) : nil
        item.hostViewControllerObject = message.hasHostViewController ? object(message.hostViewController) : nil
        item.frame = cgRect(message.frame)
        item.bounds = cgRect(message.bounds)
        item.isHidden = message.hidden
        item.alpha = message.alpha
        item.backgroundColor = message.hasBackgroundColor ? makeColor(message.backgroundColor) : nil
        item.representedAsKeyWindow = message.representedAsKeyWindow
        item.shouldCaptureImage = message.shouldCaptureImage
        item.customDisplayTitle = message.customDisplayTitle.isEmpty ? nil : message.customDisplayTitle
        item.danceuiSource = message.danceuiSource.isEmpty ? nil : message.danceuiSource
        item.customInfo = message.hasCustomInfo ? customInfo(message.customInfo) : nil
        item.attributesGroupList = message.attributeGroups.map(group)
        item.customAttrGroupList = message.customAttributeGroups.map(group)
        item.eventHandlers = message.eventHandlers.map(eventHandler)
        return item
    }

    // Pre-order with depth: a nested message per level would overflow Swift concurrency's stacks in deep hierarchies.
    public static func flatten(_ roots: [SPLKDisplayItem]) -> [SPLKV2Node] {
        var nodes: [SPLKV2Node] = []
        var stack: [(SPLKDisplayItem, UInt32)] = roots.reversed().map { ($0, 0) }
        while let (item, depth) = stack.popLast() {
            nodes.append(nodeMessage(item, depth: depth))
            for child in (item.subitems ?? []).reversed() {
                stack.append((child, depth + 1))
            }
        }
        return nodes
    }

    public static func rebuild(_ nodes: [SPLKV2Node]) -> [SPLKDisplayItem] {
        var roots: [SPLKDisplayItem] = []
        var ancestors: [SPLKDisplayItem] = []
        var children: [ObjectIdentifier: [SPLKDisplayItem]] = [:]
        for node in nodes {
            let item = displayItem(node)
            let depth = min(Int(node.depth), ancestors.count)
            ancestors.removeSubrange(depth...)
            if let parent = ancestors.last {
                children[ObjectIdentifier(parent), default: []].append(item)
            } else {
                roots.append(item)
            }
            ancestors.append(item)
        }
        // Top-down: `setSubitems:` refreshes the subtree it attaches, which stays one level deep this way.
        var pending = roots
        while let item = pending.popLast() {
            if let list = children[ObjectIdentifier(item)] {
                item.subitems = list
                pending.append(contentsOf: list)
            }
        }
        return roots
    }

    // MARK: - Hierarchy

    public static func snapshot(_ info: SPLKHierarchyInfo, version: UInt64, screen: SPLKV2ScreenInfo?) -> SPLKV2HierarchySnapshot {
        var message = SPLKV2HierarchySnapshot()
        message.version = version
        message.nodes = flatten(info.displayItems ?? [])
        message.colorAlias = colorAliasMessage(info.colorAlias ?? [:])
        message.collapsedClassList = info.collapsedClassList ?? []
        if let appInfo = info.appInfo {
            message.app = summary(appInfo, screen: screen)
        }
        return message
    }

    public static func hierarchyInfo(_ message: SPLKV2HierarchySnapshot) -> SPLKHierarchyInfo {
        let info = SPLKHierarchyInfo()
        info.displayItems = rebuild(message.nodes)
        info.colorAlias = colorAlias(message.colorAlias)
        info.collapsedClassList = message.collapsedClassList
        info.appInfo = message.hasApp ? appInfo(message.app) : nil
        return info
    }

    static func colorAliasMessage(_ alias: [String: Any]) -> [String: SPLKV2ColorAlias] {
        alias.compactMapValues { value in
            var message = SPLKV2ColorAlias()
            if let aliasColor = value as? SPLKBridgeColor, let colorMessage = color(aliasColor) {
                message.color = colorMessage
            } else if let group = value as? [String: Any] {
                var groupMessage = SPLKV2ColorAliasGroup()
                groupMessage.entries = colorAliasMessage(group)
                message.group = groupMessage
            } else {
                return nil
            }
            return message
        }
    }

    static func colorAlias(_ message: [String: SPLKV2ColorAlias]) -> [String: Any] {
        message.compactMapValues { alias -> Any? in
            switch alias.value {
            case .color(let color): return makeColor(color)
            case .group(let group): return colorAlias(group.entries)
            case nil: return nil
            }
        }
    }

    // MARK: - App

    public static func summary(_ info: SPLKAppInfo, screen: SPLKV2ScreenInfo?) -> SPLKV2AppSummary {
        var message = SPLKV2AppSummary()
        message.identifier = UInt64(info.appInfoIdentifier)
        message.name = info.appName ?? ""
        message.bundleIdentifier = info.appBundleIdentifier ?? ""
        message.deviceDescription = info.deviceDescription ?? ""
        message.osDescription = info.osDescription ?? ""
        message.osMainVersion = UInt32(info.osMainVersion)
        message.deviceType = SPLKV2AppSummary.DeviceType(rawValue: info.deviceType.rawValue + 1) ?? .unspecified
        if let screen {
            message.screen = screen
        } else {
            var screenMessage = SPLKV2ScreenInfo()
            screenMessage.size = size(CGSize(width: info.screenWidth, height: info.screenHeight))
            screenMessage.scale = info.screenScale
            message.screen = screenMessage
        }
        return message
    }

    public static func appInfoMessage(_ info: SPLKAppInfo, screen: SPLKV2ScreenInfo?) -> SPLKV2AppInfo {
        var message = SPLKV2AppInfo()
        message.summary = summary(info, screen: screen)
        message.shouldUseCache = info.shouldUseCache
        if let image = encodedImage(info.screenshot) {
            message.screenshot = image
        }
        if let image = encodedImage(info.appIcon) {
            message.icon = image
        }
        return message
    }

    public static func appInfo(_ message: SPLKV2AppSummary) -> SPLKAppInfo {
        let info = SPLKAppInfo()
        info.appInfoIdentifier = UInt(message.identifier)
        info.appName = message.name
        info.appBundleIdentifier = message.bundleIdentifier
        info.deviceDescription = message.deviceDescription
        info.osDescription = message.osDescription
        info.osMainVersion = UInt(message.osMainVersion)
        info.deviceType = SPLKAppInfoDevice(rawValue: max(message.deviceType.rawValue - 1, 0)) ?? .others
        info.screenWidth = message.screen.size.width
        info.screenHeight = message.screen.size.height
        info.screenScale = message.screen.scale
        return info
    }

    public static func appInfo(_ message: SPLKV2AppInfo) -> SPLKAppInfo {
        let info = appInfo(message.summary)
        info.shouldUseCache = message.shouldUseCache
        info.screenshot = message.hasScreenshot ? makeImage(message.screenshot) : nil
        info.appIcon = message.hasIcon ? makeImage(message.icon) : nil
        return info
    }

    // MARK: - Details

    public static func detailMessage(_ detail: SPLKDisplayItemDetail) -> SPLKV2NodeDetail {
        var message = SPLKV2NodeDetail()
        message.oid = UInt64(detail.displayItemOid)
        if let image = encodedImage(detail.groupScreenshot) {
            message.groupScreenshot = image
        }
        if let image = encodedImage(detail.soloScreenshot) {
            message.soloScreenshot = image
        }
        if let frame = rectValue(detail.frameValue) {
            message.frame = rect(frame)
        }
        if let bounds = rectValue(detail.boundsValue) {
            message.bounds = rect(bounds)
        }
        if let hidden = detail.hiddenValue {
            message.hidden = hidden.boolValue
        }
        if let alpha = detail.alphaValue {
            message.alpha = alpha.floatValue
        }
        if let title = detail.customDisplayTitle {
            message.customDisplayTitle = title
        }
        if let source = detail.danceUISource {
            message.danceuiSource = source
        }
        message.attributeGroups = (detail.attributesGroupList ?? []).map(groupMessage)
        message.customAttributeGroups = (detail.customAttrGroupList ?? []).map(groupMessage)
        if let subitems = detail.subitems {
            message.childrenSet = true
            message.children = flatten(subitems)
        }
        message.failureCode = Int32(detail.failureCode)
        return message
    }

    public static func detail(_ message: SPLKV2NodeDetail) -> SPLKDisplayItemDetail {
        let detail = SPLKDisplayItemDetail()
        detail.displayItemOid = UInt(message.oid)
        detail.groupScreenshot = message.hasGroupScreenshot ? makeImage(message.groupScreenshot) : nil
        detail.soloScreenshot = message.hasSoloScreenshot ? makeImage(message.soloScreenshot) : nil
        detail.frameValue = message.hasFrame ? makeValue(rect: cgRect(message.frame)) : nil
        detail.boundsValue = message.hasBounds ? makeValue(rect: cgRect(message.bounds)) : nil
        detail.hiddenValue = message.hasHidden ? NSNumber(value: message.hidden) : nil
        detail.alphaValue = message.hasAlpha ? NSNumber(value: message.alpha) : nil
        detail.customDisplayTitle = message.hasCustomDisplayTitle ? message.customDisplayTitle : nil
        detail.danceUISource = message.hasDanceuiSource ? message.danceuiSource : nil
        detail.attributesGroupList = message.attributeGroups.map(group)
        detail.customAttrGroupList = message.customAttributeGroups.map(group)
        detail.subitems = message.childrenSet ? rebuild(message.children) : nil
        detail.failureCode = Int(message.failureCode)
        return detail
    }

    // MARK: - Tasks

    public static func taskMessage(_ task: SPLKStaticAsyncUpdateTask) -> SPLKV2DetailTask {
        var message = SPLKV2DetailTask()
        message.oid = UInt64(task.oid)
        message.screenshot = SPLKV2DetailTask.Screenshot(rawValue: task.taskType.rawValue) ?? .none
        message.attrRequest = SPLKV2DetailTask.AttrRequest(rawValue: task.attrRequest.rawValue) ?? .attrAutomatic
        message.needBasicVisualInfo = task.needBasisVisualInfo
        message.needSubitems = task.needSubitems
        message.frameSize = size(task.frameSize)
        return message
    }

    public static func task(_ message: SPLKV2DetailTask, clientVersion: String) -> SPLKStaticAsyncUpdateTask {
        let task = SPLKStaticAsyncUpdateTask()
        task.oid = UInt(message.oid)
        task.taskType = SPLKStaticAsyncUpdateTaskType(rawValue: message.screenshot.rawValue) ?? .noScreenshot
        task.attrRequest = SPLKDetailUpdateTaskAttrRequest(rawValue: message.attrRequest.rawValue) ?? .automatic
        task.needBasisVisualInfo = message.needBasicVisualInfo
        task.needSubitems = message.needSubitems
        task.clientReadableVersion = clientVersion
        task.frameSize = cgSize(message.frameSize)
        return task
    }

    public static func packageMessage(_ package: SPLKStaticAsyncUpdateTasksPackage) -> SPLKV2DetailTaskPackage {
        var message = SPLKV2DetailTaskPackage()
        message.tasks = (package.tasks ?? []).map(taskMessage)
        return message
    }

    public static func package(_ message: SPLKV2DetailTaskPackage, clientVersion: String) -> SPLKStaticAsyncUpdateTasksPackage {
        let package = SPLKStaticAsyncUpdateTasksPackage()
        package.tasks = message.tasks.map { task($0, clientVersion: clientVersion) }
        return package
    }

    // MARK: - Modifications

    public static func modificationMessage(_ modification: SPLKAttributeModification) -> SPLKV2ModifyAttribute {
        var message = SPLKV2ModifyAttribute()
        message.targetOid = UInt64(modification.targetOid)
        message.setter = modification.setterSelector.map { NSStringFromSelector($0) } ?? ""
        message.getter = modification.getterSelector.map { NSStringFromSelector($0) } ?? ""
        message.type = SPLKV2AttrType(rawValue: modification.attrType.rawValue) ?? .attrNone
        if let value = valueMessage(modification.value, type: modification.attrType, identifier: nil) {
            message.value = value
        }
        return message
    }

    public static func modification(_ message: SPLKV2ModifyAttribute, clientVersion: String) -> SPLKAttributeModification {
        let modification = SPLKAttributeModification()
        modification.targetOid = UInt(message.targetOid)
        modification.setterSelector = message.setter.isEmpty ? nil : NSSelectorFromString(message.setter)
        modification.getterSelector = message.getter.isEmpty ? nil : NSSelectorFromString(message.getter)
        modification.attrType = SPLKAttrType(rawValue: message.type.rawValue) ?? .none
        modification.value = objectValue(message.hasValue ? message.value : nil, type: modification.attrType, identifier: nil)
        modification.clientReadableVersion = clientVersion
        return modification
    }

    public static func customModificationMessage(_ modification: SPLKCustomAttrModification) -> SPLKV2ModifyCustomAttribute {
        var message = SPLKV2ModifyCustomAttribute()
        message.customSetterID = modification.customSetterID ?? ""
        message.type = SPLKV2AttrType(rawValue: modification.attrType.rawValue) ?? .attrNone
        if let value = valueMessage(modification.value, type: modification.attrType, identifier: nil) {
            message.value = value
        }
        return message
    }

    public static func customModification(_ message: SPLKV2ModifyCustomAttribute) -> SPLKCustomAttrModification {
        let modification = SPLKCustomAttrModification()
        modification.customSetterID = message.customSetterID
        modification.attrType = SPLKAttrType(rawValue: message.type.rawValue) ?? .none
        modification.value = objectValue(message.hasValue ? message.value : nil, type: modification.attrType, identifier: nil)
        return modification
    }
}

#endif
