//
//  LKConsoleReturnRowView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/1.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKConsoleReturnRowView: LKTableRowView {

    private let insets = NSEdgeInsets(top: 0, left: ConsoleInsetLeft, bottom: 5, right: ConsoleInsetRight)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        titleLabel.isSelectable = true
        titleLabel.textColor = .labelColor
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.maximumNumberOfLines = 0
    }

    override func layout() {
        super.layout()
        titleLabel.setX(insets.left).extendToRight(insets.right).fitHeight().setY(insets.top)
    }

    func height(forWidth width: CGFloat) -> CGFloat {
        var height = titleLabel.sizeThatFits(NSSize(width: width - insets.left - insets.right, height: .greatestFiniteMagnitude)).height
        height += insets.top + insets.bottom
        return height
    }
}
