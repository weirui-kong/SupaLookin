//
//  LookinAutoLayoutConstraint+LookinClient.swift
//  SupaLookin
//
//  Created by likai.123 on 2024/1/14.
//  Copyright © 2024 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

extension LookinAutoLayoutConstraint {

    static func description(withItemObject object: LookinObject?, type: LookinConstraintItemType, detailed: Bool) -> String {
        switch type {
        case .`nil`:
            return detailed ? "Nil" : "nil"
        case .`self`:
            return detailed ? "Self" : "self"
        case .`super`:
            return detailed ? "Superview" : "super"
        case .view, .layoutGuide:
            return detailed ? "<\(object?.rawClassName() ?? ""): \(object?.memoryAddress ?? "")>" : "(\(object?.simpleDemangledClassName ?? "")*)"
        default:
            assertionFailure()
            return detailed ? "<\(object?.rawClassName() ?? ""): \(object?.memoryAddress ?? "")>" : "(\(object?.rawClassName() ?? "")*)"
        }
    }

    // 注意 iOS 和 macOS 虽然都有 NSLayoutAttribute 但是 value 非常不同，这里应该去 iOS 平台查看 NSLayoutAttribute 的对应
    static func description(withAttributeInt attribute: Int) -> String {
        switch attribute {
        case 0:
            // 在某些业务里确实会出现这种情况，在 Reveal 和 UI Debugger 里也是这么显示的
            return "notAnAttribute"
        case 1: return "left"
        case 2: return "right"
        case 3: return "top"
        case 4: return "bottom"
        case 5: return "leading"
        case 6: return "trailing"
        case 7: return "width"
        case 8: return "height"
        case 9: return "centerX"
        case 10: return "centerY"
        case 11: return "lastBaseline"
        case 12: return "firstBaseline"
        case 13: return "leftMargin"
        case 14: return "rightMargin"
        case 15: return "topMargin"
        case 16: return "bottomMargin"
        case 17: return "leadingMargin"
        case 18: return "trailingMargin"
        case 19: return "centerXWithinMargins"
        case 20: return "centerYWithinMargins"
        // 以下都是和 AutoResizingMask 有关的，这里的定义是从系统 UI Debugger 里抄过来的，暂时没在官方文档里发现它们的公开定义
        case 32: return "minX"
        case 33: return "minY"
        case 34: return "midX"
        case 35: return "midY"
        case 36: return "maxX"
        case 37: return "maxY"
        default:
            assertionFailure()
            return "unknownAttr(\(attribute))"
        }
    }

    static func symbol(withRelation relation: NSLayoutConstraint.Relation) -> String {
        switch relation.rawValue {
        case -1: return "<="
        case 0: return "="
        case 1: return ">="
        default:
            assertionFailure()
            return "?"
        }
    }

    static func description(withRelation relation: NSLayoutConstraint.Relation) -> String {
        switch relation.rawValue {
        case -1: return "LessThanOrEqual"
        case 0: return "Equal"
        case 1: return "GreaterThanOrEqual"
        default:
            assertionFailure()
            return "?"
        }
    }
}
