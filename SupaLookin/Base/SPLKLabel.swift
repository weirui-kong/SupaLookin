//
//  SPLKLabel.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/8/4.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

class SPLKLabel: NSTextField {

    /// 默认为 nil
    var textColors: SPLKTwoColors? {
        didSet {
            updateColors()
        }
    }

    /// 默认为 nil
    var backgroundColors: SPLKTwoColors? {
        didSet {
            updateColors()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        backgroundColor = .clear
        isBezeled = false
        drawsBackground = true
        isEditable = false
        isSelectable = false
        updateColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        if let textColors {
            textColor = textColors.color
        }
        if let backgroundColors {
            backgroundColor = backgroundColors.color
        }
    }
}
