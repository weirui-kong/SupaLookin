//
//  LKPopPanel.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/9/28.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKPopPanel: NSPanel {

    init(size: NSSize) {
        // 如果不是 nonactivatingPanel 的话，当显示该 window 时点击别的 app，整个 Lookin 窗口都会被隐藏，不知道为什么
        super.init(contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height), styleMask: .nonactivatingPanel, backing: .buffered, defer: true)
        let contentView = LKBaseView()
        contentView.layer?.cornerRadius = 6
        contentView.layer?.borderWidth = 1
        contentView.didChangeAppearanceBlock = { view, isDarkMode in
            view.backgroundColor = isDarkMode ? NSColor(lookinRed: 44, green: 44, blue: 44) : NSColor(lookinRed: 236, green: 236, blue: 236)
            view.layer?.borderColor = isDarkMode ? NSColor.separatorDarkModeColor.cgColor : NSColor.separatorLightModeColor.cgColor
        }
        self.contentView = contentView
        backgroundColor = .clear
    }

    // 如果没有这一句，window 里的输入框将无法触发编辑
    override var canBecomeKey: Bool {
        true
    }
}
