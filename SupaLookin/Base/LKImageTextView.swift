//
//  LKImageTextView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/19.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKImageTextView: LKBaseView {

    let imageView = NSImageView()
    let label = LKLabel()

    var imageMargins = HorizontalMargins()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(label)
    }

    override func layout() {
        super.layout()
        imageView.fitSize().setX(imageMargins.left).centerVertically()
        label.setX(imageView.frame.maxX + imageMargins.right).extendToRight(0).fitHeight().centerVertically()
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        let labelSize = label.sizeThatFits(.max)
        let imageSize = imageView.image?.size ?? .zero
        return NSSize(width: imageMargins.left + imageSize.width + imageMargins.right + labelSize.width,
                      height: max(imageSize.height, labelSize.height))
    }
}
