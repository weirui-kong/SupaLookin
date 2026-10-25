//
//  NSButton+LookinClient.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/25.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

extension NSButton {

    /// size 已经被设置好
    static func normalButton(title: String, action: @escaping (NSButton) -> Void) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .rounded
        button.title = title
        button.font = .systemFont(ofSize: 13)
        button.onAction(action)
        button.frame = NSRect(x: 0, y: 0, width: 84, height: 40)
        return button
    }

    /// 只有图片的按钮，没有 border。可以手动设置高度与宽度。
    static func imageButton(_ image: NSImage?, action: @escaping (NSButton) -> Void) -> NSButton {
        let button = NSButton()
        button.image = image
        button.bezelStyle = .roundRect
        button.isBordered = false
        button.onAction(action)
        return button
    }
}
