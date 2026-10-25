//
//  LookinDisplayItem+LookinClient.swift
//  SupaLookin
//
//  Created by likaimacbookhome on 2023/11/1.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

extension LookinDisplayItem {

    /// 该 item 在左侧 hierarchy 中显示的字符串，通常是类名
    var title: String? {
        if let customInfo {
            return customInfo.title
        } else if let customDisplayTitle, !customDisplayTitle.isEmpty {
            return customDisplayTitle
        } else if let viewObject {
            return viewObject.simpleDemangledClassName
        } else if let layerObject {
            return layerObject.simpleDemangledClassName
        }
        return nil
    }

    var subtitle: String? {
        if let customInfo {
            return customInfo.subtitle
        }

        if let text = hostViewControllerObject?.simpleDemangledClassName, !text.isEmpty {
            return "\(text).view"
        }

        let representedObject = viewObject ?? layerObject
        if let specialTrace = representedObject?.specialTrace, !specialTrace.isEmpty {
            return specialTrace
        }
        if let ivarTraces = representedObject?.ivarTraces, !ivarTraces.isEmpty {
            let ivarNameList = ivarTraces.compactMap(\.ivarName)
            // NSSet keeps the de-duplicated order identical to the Objective-C app's
            let names = NSSet(array: ivarNameList).allObjects.compactMap { $0 as? String }
            return names.joined(separator: "   ")
        }

        return nil
    }

    /// className 以 “UI”、“CA” 等开头时认为是系统类，该属性将返回 true
    var representedForSystemClass: Bool {
        let title = title ?? ""
        return title.hasPrefix("UI") || title.hasPrefix("CA") || title.hasPrefix("_")
    }

    /// 返回 soloScreenshot 或 groupScreenshot
    var appropriateScreenshot: NSImage? {
        if isExpandable && isExpanded {
            return soloScreenshot
        }
        return groupScreenshot
    }

    var isUserCustom: Bool {
        customInfo != nil
    }

    /// 是否有能力显示图层框
    var hasPreviewBoxAbility: Bool {
        guard let customInfo else {
            return true
        }
        return customInfo.hasValidFrame()
    }

    var hasValidFrameToRoot: Bool {
        if let customInfo {
            return customInfo.hasValidFrame()
        }
        return LKHelper.validateFrame(frame)
    }

    /// 当 hasValidFrameToRoot 返回 false 时，该方法返回的值无意义
    func calculateFrameToRoot() -> CGRect {
        if let customInfo {
            return customInfo.frameInWindow?.rectValue ?? .zero
        }
        guard let `super` else {
            return frame
        }
        let superFrameToRoot = `super`.calculateFrameToRoot()
        let superBounds = `super`.bounds
        let selfFrame = frame

        let x = selfFrame.origin.x - superBounds.origin.x + superFrameToRoot.origin.x
        let y = selfFrame.origin.y - superBounds.origin.y + superFrameToRoot.origin.y
        return CGRect(x: x, y: y, width: selfFrame.size.width, height: selfFrame.size.height)
    }

    /// 在 string 这个搜索词下，如果该 displayItem 应该被搜索到，则该方法返回 true。string 不能为空字符串
    func isMatched(withSearchString string: String) -> Bool {
        guard !string.isEmpty else {
            assertionFailure()
            return false
        }
        let searchString = string.lowercased()
        if title?.lowercased().contains(searchString) == true {
            return true
        }
        if subtitle?.lowercased().contains(searchString) == true {
            return true
        }
        if viewObject?.memoryAddress?.contains(searchString) == true {
            return true
        }
        if layerObject?.memoryAddress?.contains(searchString) == true {
            return true
        }
        return false
    }

    /// 遍历自身和所有上级元素，block 返回 true 时停止
    func enumerateSelfAndAncestors(_ block: (LookinDisplayItem) -> Bool) {
        var item: LookinDisplayItem? = self
        while let current = item {
            if block(current) {
                break
            }
            item = current.`super`
        }
    }

    func enumerateAncestors(_ block: (LookinDisplayItem) -> Bool) {
        `super`?.enumerateSelfAndAncestors(block)
    }

    /// 遍历自身后所有下级元素
    func enumerateSelfAndChildren(_ block: (LookinDisplayItem) -> Void) {
        block(self)
        subitems?.forEach { $0.enumerateSelfAndChildren(block) }
    }

    func itemIsKindOfClass(withName className: String) -> Bool {
        itemIsKindOfClasses(withNames: [className])
    }

    func itemIsKindOfClasses(withNames targetClassNames: Set<String>) -> Bool {
        guard !targetClassNames.isEmpty, let selfObj = viewObject ?? layerObject else {
            return false
        }
        let classChain = (selfObj.classChainList ?? []).map { $0.components(separatedBy: ".").last ?? $0 }
        return targetClassNames.contains { classChain.contains($0) }
    }
}
