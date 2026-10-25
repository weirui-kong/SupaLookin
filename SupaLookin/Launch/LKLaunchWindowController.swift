//
//  LKLaunchWindowController.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/3.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKLaunchWindowController: LKWindowController {

    let launchViewController: LKLaunchViewController

    init() {
        let window = LKWindow(contentRect: NSRect(x: 0, y: 0, width: 252, height: 400), styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: true)
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()

        launchViewController = LKLaunchViewController(window: window)
        super.init(window: window)
        window.contentView = launchViewController.view
        contentViewController = launchViewController
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
