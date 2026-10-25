//
//  LKInputSearchSuggestionsRowView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/3.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKInputSearchSuggestionsRowView: NSTableRowView {

    let titleLabel = LKLabel()
    let imageView = NSImageView()

    private let horInset: CGFloat = 10
    private let titleLeft: CGFloat = 5

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)

        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.font = .systemFont(ofSize: 14)
        addSubview(titleLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        imageView.fitSize().setX(horInset).centerVertically()
        titleLabel.setX(imageView.frame.maxX + titleLeft).extendToRight(horInset).fitHeight().centerVertically().offset(y: -1)
    }

    func bestWidth() -> CGFloat {
        horInset * 2 + (imageView.image?.size.width ?? 0) + titleLeft + titleLabel.sizeThatFits(.max).width
    }

    override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            let color = NSAppearance.currentDrawing().isDarkMode ? LKHelper.accentColor : NSColor(lookinRed: 0, green: 0, blue: 0, alpha: 0.24)
            color.setFill()
            NSBezierPath(rect: bounds).fill()
        }
    }
}
