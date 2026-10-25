//
//  LKJSONAttributeWindowController.swift
//  SupaLookin
//
//  Created by likai.123 on 2023/12/4.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKJSONAttributeWindowController: LKWindowController {

    init() {
        let window = LKWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 320), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: true)
        window.isMovableByWindowBackground = true
        window.titleVisibility = .hidden
        window.minSize = CGSize(width: 200, height: 200)
        window.center()

        super.init(window: window)
        let vc = LKJSONAttributeViewController()
        window.contentView = vc.view
        contentViewController = vc
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
