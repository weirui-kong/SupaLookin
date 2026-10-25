//
//  LKBaseControl.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/8/28.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

class LKBaseControl: NSControl {

    var clickAction: ((LKBaseControl) -> Void)?

    var adjustAlphaWhenClick = false

    var didChangeAppearance: ((LKBaseControl, Bool) -> Void)? {
        didSet {
            triggerDidChangeAppearanceBlock()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if adjustAlphaWhenClick {
            alphaValue = 0.8
        }
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        triggerClickAction()
        if adjustAlphaWhenClick {
            alphaValue = 1
        }
    }

    func triggerClickAction() {
        clickAction?(self)
    }

    override func viewDidChangeEffectiveAppearance() {
        triggerDidChangeAppearanceBlock()
    }

    private func triggerDidChangeAppearanceBlock() {
        didChangeAppearance?(self, effectiveAppearance.isDarkMode)
    }

    override func sizeToFit() {
        setSize(bestSize)
    }

    /// 如果子类返回 true，则 mouseEntered 和 mouseExited 会被调用。默认为 false
    var shouldTrackMouseEnteredAndExited: Bool {
        false
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        guard shouldTrackMouseEnteredAndExited else {
            return
        }
        trackingAreas.forEach { removeTrackingArea($0) }
        let newArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(newArea)
    }
}
