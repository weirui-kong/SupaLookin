//
//  LKConsoleSubmitRowView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/1.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKConsoleSubmitRowView: LKTableRowView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        titleLabel.isSelectable = true
        titleLabel.font = .systemFont(ofSize: 13)

        subtitleLabel.isSelectable = true
        subtitleLabel.textColor = .labelColor
        subtitleLabel.font = .systemFont(ofSize: 13)
    }

    override func layout() {
        super.layout()
        var titleSize = titleLabel.sizeThatFits(.max)
        titleSize.width = min(titleSize.width, frame.width * 0.5)
        titleLabel.setX(ConsoleInsetLeft).setWidth(titleSize.width).setHeight(titleSize.height).centerVertically()
        subtitleLabel.setX(titleLabel.frame.maxX + 5).extendToRight(ConsoleInsetRight).fitHeight().centerVertically()
    }

    override func isDarkModeDidChange() {
        super.isDarkModeDidChange()
        titleLabel.textColor = isDarkMode ? NSColor(lookinRed: 85, green: 200, blue: 95) : NSColor(lookinRed: 54, green: 155, blue: 62)
    }
}
