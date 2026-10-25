//
//  LKAboutWindowController.swift
//  SupaLookin
//
//  Created by 李凯 on 2019/10/30.
//  Copyright © 2019 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKAboutWindowController: LKWindowController {

    init() {
        let width: CGFloat = 500
        let height = width * 0.54

        let window = LKWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.titled, .closable], backing: .buffered, defer: true)
        window.isMovableByWindowBackground = true
        window.center()

        super.init(window: window)
        let vc = LKAboutViewController()
        window.contentView = vc.view
        contentViewController = vc
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
