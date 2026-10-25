//
//  LKImageControl.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/9/1.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

class LKImageControl: LKBaseControl {

    let imageView = NSImageView()

    var image: NSImage? {
        didSet {
            imageView.image = image
            needsLayout = true
        }
    }

    convenience init(image: NSImage?) {
        self.init(frame: .zero)
        self.image = image
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView.wantsLayer = true
        addSubview(imageView)
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
        imageView.layer?.anchorPoint = NSPoint(x: 0.5, y: 0.5)
        imageView.layer?.frame = imageView.frame
    }

    override func sizeThatFits(_ size: NSSize) -> NSSize {
        imageView.image?.size ?? .zero
    }
}
