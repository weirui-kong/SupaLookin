//
//  LKDashboardAttributeConstraintsItemControl.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/9/28.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKDashboardAttributeConstraintsItemControl: LKTextControl {

    var constraint: LookinAutoLayoutConstraint? {
        didSet {
            label.stringValue = constraint.map { string(from: $0) } ?? ""
            updateLabelColor()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.alignment = .left
        label.font = .systemFont(ofSize: 12)
        didChangeAppearance = { [weak self] _, _ in
            self?.updateLabelColor()
        }
    }

    private func updateLabelColor() {
        if constraint?.effective == true {
            label.textColor = .labelColor
        } else {
            if effectiveAppearance.isDarkMode {
                label.textColor = NSColor(lookinRed: 130, green: 131, blue: 132)
            } else {
                label.textColor = NSColor(lookinRed: 150, green: 151, blue: 152)
            }
        }
    }

    private func string(from constraint: LookinAutoLayoutConstraint) -> String {
        var string = "\(LookinAutoLayoutConstraint.description(withItemObject: constraint.firstItem, type: constraint.firstItemType, detailed: false)).\(LookinAutoLayoutConstraint.description(withAttributeInt: constraint.firstAttribute)) \(LookinAutoLayoutConstraint.symbol(withRelation: constraint.relation))"

        if constraint.secondAttribute == 0 {
            string += " \(NSString.lookin_string(from: constraint.constant, decimal: 3) ?? "")"
        } else {
            string += " \(LookinAutoLayoutConstraint.description(withItemObject: constraint.secondItem, type: constraint.secondItemType, detailed: false)).\(LookinAutoLayoutConstraint.description(withAttributeInt: constraint.secondAttribute))"

            if constraint.multiplier != 1 {
                string += " * \(NSString.lookin_string(from: constraint.multiplier, decimal: 3) ?? "")"
            }
            if constraint.constant > 0 {
                string += " + \(NSString.lookin_string(from: constraint.constant, decimal: 3) ?? "")"
            } else if constraint.constant < 0 {
                string += " - \(NSString.lookin_string(from: -constraint.constant, decimal: 3) ?? "")"
            }
        }

        if constraint.priority != 1000 {
            string += " @ \(NSNumber(value: constraint.priority))"
        }

        return string
    }

    override var shouldTrackMouseEnteredAndExited: Bool {
        true
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        alphaValue = 0.5
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        alphaValue = 1
    }
}
