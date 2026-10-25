//
//  LKWindowToolbarScaleView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/10/14.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKWindowToolbarScaleView: LKBaseView {

    let slider = NSSlider()
    private(set) var decreaseButton: NSButton!
    private(set) var increaseButton: NSButton!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(slider)

        let decrease = NSButton()
        decrease.image = NSImage(named: "icon_decrease")
        decrease.bezelStyle = .roundRect
        decrease.isBordered = false
        addSubview(decrease)
        decreaseButton = decrease

        let increase = NSButton()
        increase.image = NSImage(named: "icon_increase")
        increase.bezelStyle = .roundRect
        increase.isBordered = false
        addSubview(increase)
        increaseButton = increase
    }

    override func layout() {
        super.layout()
        decreaseButton.setWidth(20).fillHeight().setX(0)
        increaseButton.setWidth(20).fillHeight().alignRight(0)
        slider.fillHeight().setX(decreaseButton.frame.maxX).extendToMaxX(increaseButton.frame.minX)
    }
}
