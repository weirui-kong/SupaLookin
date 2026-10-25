//
//  LKPreferenceWindowController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/1/4.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKPreferenceWindowController: LKWindowController {

    init() {
        let window = LKWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 440), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: true)
        window.isMovableByWindowBackground = true
        window.title = NSLocalizedString("Preferences", comment: "")
        window.center()

        super.init(window: window)
        let vc = LKPreferenceViewController()
        window.contentView = vc.view
        contentViewController = vc
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
