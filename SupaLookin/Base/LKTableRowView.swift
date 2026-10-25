//
//  LKTableRowView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/4/20.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

class LKTableRowView: NSTableRowView {

    let titleLabel = LKLabel()
    let subtitleLabel = LKLabel()

    private let backgroundColorLayer = CALayer()

    /// Kept apart from NSTableRowView's own isSelected: in Objective-C this property's setIsSelected: never touched AppKit's setSelected:.
    var isRowSelected = false {
        didSet {
            if oldValue != isRowSelected {
                updateBackgroundLayerColor()
            }
        }
    }

    var isHovered = false {
        didSet {
            if oldValue != isHovered {
                updateBackgroundLayerColor()
            }
        }
    }

    /// 子类可在 didSet 里更新 UI
    var isDarkMode = false {
        didSet {
            isDarkModeDidChange()
        }
    }

    weak var horizontalScrollWidthManager: LKTableViewHorizontalScrollWidthManager?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        backgroundColorLayer.lookin_removeImplicitAnimations()
        layer?.addSublayer(backgroundColorLayer)

        titleLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(titleLabel)

        addSubview(subtitleLabel)

        isDarkMode = effectiveAppearance.isDarkMode
        isDarkModeDidChange()

        updateBackgroundLayerColor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 子类可在该方法里更新 UI，重写时须调用 super
    func isDarkModeDidChange() {
    }

    override func layout() {
        super.layout()
        backgroundColorLayer.fillSuperview()
    }

    override var isFlipped: Bool {
        true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        isDarkMode = effectiveAppearance.isDarkMode
        updateBackgroundLayerColor()
    }

    private func updateBackgroundLayerColor() {
        if isRowSelected {
            backgroundColorLayer.backgroundColor = LKHelper.accentColor.cgColor
        } else if isHovered {
            backgroundColorLayer.backgroundColor = isDarkMode ? NSColor(lookinRed: 255, green: 255, blue: 255, alpha: 0.15).cgColor : NSColor(lookinRed: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        } else {
            backgroundColorLayer.backgroundColor = NSColor.clear.cgColor
        }
    }
}

final class LKTableBlankRowView: LKTableRowView {
}
