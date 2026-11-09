//
//  SPLKBridge+Values.swift
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

    // The attribute value table of 20261110-protocol-v2-m2-server.md.
    public static func valueMessage(_ value: Any?, type: SPLKAttrType, identifier: String?) -> SPLKV2Value? {
        var message = SPLKV2Value()
        switch type {
        case .none, .void:
            return nil
        default:
            break
        }
        guard let value, !(value is NSNull) else {
            message.nullValue = SPLKV2Empty()
            return message
        }
        switch type {
        case .char, .int, .short, .long, .longLong, .enumInt, .enumLong:
            guard let number = value as? NSNumber else { return mismatch(value, type) }
            message.intValue = number.int64Value
        case .unsignedChar, .unsignedInt, .unsignedShort, .unsignedLong, .unsignedLongLong:
            guard let number = value as? NSNumber else { return mismatch(value, type) }
            message.uintValue = number.uint64Value
        case .float, .double:
            guard let number = value as? NSNumber else { return mismatch(value, type) }
            message.doubleValue = number.doubleValue
        case .BOOL:
            guard let number = value as? NSNumber else { return mismatch(value, type) }
            message.boolValue = number.boolValue
        case .sel, .class, .nsString, .enumString, .json:
            guard let string = value as? String else { return mismatch(value, type) }
            message.stringValue = string
        case .cgPoint:
            guard let point = pointValue(value) else { return mismatch(value, type) }
            message.point = self.point(point)
        case .cgVector:
            guard let vector = structValue(value, as: CGVector.self, encoding: vectorEncoding) else { return mismatch(value, type) }
            message.point = point(CGPoint(x: vector.dx, y: vector.dy))
        case .uiOffset:
            guard let offset = structValue(value, as: Vector2.self, encoding: offsetEncoding) else { return mismatch(value, type) }
            message.point = point(CGPoint(x: offset.first, y: offset.second))
        case .cgSize:
            guard let size = sizeValue(value) else { return mismatch(value, type) }
            message.size = self.size(size)
        case .cgRect:
            guard let rect = rectValue(value) else { return mismatch(value, type) }
            message.rect = self.rect(rect)
        case .cgAffineTransform:
            guard let transform = structValue(value, as: CGAffineTransform.self, encoding: transformEncoding) else { return mismatch(value, type) }
            var transformMessage = SPLKV2AffineTransform()
            transformMessage.a = Double(transform.a)
            transformMessage.b = Double(transform.b)
            transformMessage.c = Double(transform.c)
            transformMessage.d = Double(transform.d)
            transformMessage.tx = Double(transform.tx)
            transformMessage.ty = Double(transform.ty)
            message.transform = transformMessage
        case .uiEdgeInsets:
            guard let insets = insetsMessage(value) else { return mismatch(value, type) }
            message.insets = insets
        case .uiColor:
            guard let components = value as? [Any], let color = color(rgba: components) else { return mismatch(value, type) }
            message.color = color
        case .shadow:
            guard let info = value as? [String: Any] else { return mismatch(value, type) }
            var shadow = SPLKV2Shadow()
            if let components = info["color"] as? [Any], let color = color(rgba: components) {
                shadow.color = color
            }
            if let offset = sizeValue(info["offset"]) {
                shadow.offset = size(offset)
            }
            shadow.opacity = (info["opacity"] as? NSNumber)?.doubleValue ?? 0
            shadow.radius = (info["radius"] as? NSNumber)?.doubleValue ?? 0
            message.shadow = shadow
        case .customObj:
            return customObjectMessage(value, identifier: identifier) ?? mismatch(value, type)
        case .none, .void:
            return nil
        @unknown default:
            return mismatch(value, type)
        }
        return message
    }

    private static func customObjectMessage(_ value: Any, identifier: String?) -> SPLKV2Value? {
        var message = SPLKV2Value()
        switch identifier {
        case SPLKAttr_Class_Class_Class:
            guard let lists = value as? [[String]] else { return nil }
            message.list = list(lists.map { strings in
                var inner = SPLKV2Value()
                inner.list = list(strings.map(stringValue))
                return inner
            })
        case SPLKAttr_Relation_Relation_Relation:
            guard let strings = value as? [String] else { return nil }
            message.list = list(strings.map(stringValue))
        case SPLKAttr_AutoLayout_Constraints_Constraints:
            guard let constraints = value as? [SPLKAutoLayoutConstraint] else { return nil }
            message.list = list(constraints.map { constraint in
                var inner = SPLKV2Value()
                inner.constraint = constraintMessage(constraint)
                return inner
            })
        case SPLKAttr_UIVisualEffectView_Style_Style:
            guard let number = value as? NSNumber else { return nil }
            message.intValue = number.int64Value
        case SPLKAttr_UIImageView_Open_Open:
            guard let number = value as? NSNumber else { return nil }
            message.uintValue = number.uint64Value
        case SPLKAttr_UITableView_RowsNumber_Number:
            guard let numbers = value as? [NSNumber] else { return nil }
            message.list = list(numbers.map { number in
                var inner = SPLKV2Value()
                inner.intValue = number.int64Value
                return inner
            })
        default:
            return nil
        }
        return message
    }

    private static func list(_ values: [SPLKV2Value]) -> SPLKV2ValueList {
        var list = SPLKV2ValueList()
        list.values = values
        return list
    }

    private static func stringValue(_ string: String) -> SPLKV2Value {
        var value = SPLKV2Value()
        value.stringValue = string
        return value
    }

    private static func mismatch(_ value: Any, _ type: SPLKAttrType) -> SPLKV2Value {
        assertionFailure("SPLKModelBridge - \(Swift.type(of: value)) doesn't fit attribute type \(type.rawValue)")
        var message = SPLKV2Value()
        message.nullValue = SPLKV2Empty()
        return message
    }

    public static func objectValue(_ message: SPLKV2Value?, type: SPLKAttrType, identifier: String?) -> Any? {
        guard let message, let kind = message.kind else { return nil }
        switch kind {
        case .nullValue:
            return nil
        case .intValue(let value):
            return NSNumber(value: value)
        case .uintValue(let value):
            return NSNumber(value: value)
        case .doubleValue(let value):
            return NSNumber(value: value)
        case .boolValue(let value):
            return NSNumber(value: value)
        case .stringValue(let value):
            return value
        case .point(let point):
            switch type {
            case .cgVector:
                return makeStructValue(CGVector(dx: point.x, dy: point.y), encoding: vectorEncoding)
            case .uiOffset:
                return makeStructValue(Vector2(first: point.x, second: point.y), encoding: offsetEncoding)
            default:
                return makeValue(point: cgPoint(point))
            }
        case .size(let size):
            return makeValue(size: cgSize(size))
        case .rect(let rect):
            return makeValue(rect: cgRect(rect))
        case .insets(let insets):
            return makeValue(insets: insets)
        case .transform(let transform):
            let value = CGAffineTransform(a: transform.a, b: transform.b, c: transform.c, d: transform.d, tx: transform.tx, ty: transform.ty)
            return makeStructValue(value, encoding: transformEncoding)
        case .color(let color):
            return rgbaArray(color)
        case .shadow(let shadow):
            var info: [String: Any] = [
                "opacity": NSNumber(value: shadow.opacity),
                "radius": NSNumber(value: shadow.radius),
            ]
            if shadow.hasColor {
                info["color"] = rgbaArray(shadow.color)
            }
            if shadow.hasOffset {
                info["offset"] = makeValue(size: cgSize(shadow.offset))
            }
            return info
        case .constraint(let constraint):
            return self.constraint(constraint)
        case .list(let list):
            return list.values.map { objectValue($0, type: type, identifier: identifier) ?? NSNull() }
        }
    }

    // MARK: - Constraints

    static func constraintMessage(_ constraint: SPLKAutoLayoutConstraint) -> SPLKV2Constraint {
        var message = SPLKV2Constraint()
        message.effective = constraint.effective
        message.active = constraint.active
        if let item = constraint.firstItem {
            message.firstItem = objectRef(item)
        }
        message.firstItemType = SPLKV2ConstraintItemType(rawValue: constraint.firstItemType.rawValue) ?? .itemUnknown
        message.firstAttribute = Int32(constraint.firstAttribute)
        message.relation = Int32(constraint.relation.rawValue)
        if let item = constraint.secondItem {
            message.secondItem = objectRef(item)
        }
        message.secondItemType = SPLKV2ConstraintItemType(rawValue: constraint.secondItemType.rawValue) ?? .itemUnknown
        message.secondAttribute = Int32(constraint.secondAttribute)
        message.multiplier = Double(constraint.multiplier)
        message.constant = Double(constraint.constant)
        message.priority = Double(constraint.priority)
        message.identifier = constraint.identifier ?? ""
        return message
    }

    static func constraint(_ message: SPLKV2Constraint) -> SPLKAutoLayoutConstraint {
        let constraint = SPLKAutoLayoutConstraint()
        constraint.effective = message.effective
        constraint.active = message.active
        constraint.firstItem = message.hasFirstItem ? object(message.firstItem) : nil
        constraint.firstItemType = SPLKConstraintItemType(rawValue: message.firstItemType.rawValue) ?? .unknown
        constraint.firstAttribute = Int(message.firstAttribute)
        constraint.relation = NSLayoutConstraint.Relation(rawValue: Int(message.relation)) ?? .equal
        constraint.secondItem = message.hasSecondItem ? object(message.secondItem) : nil
        constraint.secondItemType = SPLKConstraintItemType(rawValue: message.secondItemType.rawValue) ?? .unknown
        constraint.secondAttribute = Int(message.secondAttribute)
        constraint.multiplier = CGFloat(message.multiplier)
        constraint.constant = CGFloat(message.constant)
        constraint.priority = CGFloat(message.priority)
        constraint.identifier = message.identifier.isEmpty ? nil : message.identifier
        return constraint
    }
}

#endif
