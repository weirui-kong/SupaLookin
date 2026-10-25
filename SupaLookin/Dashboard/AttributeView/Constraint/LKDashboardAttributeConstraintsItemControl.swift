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
            label.stringValue = constraint?.summaryText ?? ""
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
