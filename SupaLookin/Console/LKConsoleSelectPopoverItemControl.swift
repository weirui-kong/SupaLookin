//
//  LKConsoleSelectPopoverItemControl.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/19.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKConsoleSelectPopoverItemControl: LKBaseControl {

    private let imageView = NSImageView()
    private let titleLabel = LKLabel()
    private let subtitleLabel = LKLabel()

    private let subtitleMarginTop: CGFloat = 0

    var isChecked = false {
        didSet {
            imageView.isHidden = !isChecked
        }
    }

    var title: String? {
        didSet {
            titleLabel.stringValue = title ?? ""
            needsLayout = true
        }
    }

    var subtitle: String? {
        didSet {
            subtitleLabel.stringValue = subtitle ?? ""
            subtitleLabel.isHidden = subtitle?.isEmpty ?? true
            needsLayout = true
        }
    }

    var representedObject: LookinObject? {
        didSet {
            titleLabel.textColor = representedObject != nil ? .labelColor : .secondaryLabelColor
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView.image = NSImage(named: "Console_Checked")
        addSubview(imageView)

        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.maximumNumberOfLines = 1
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(titleLabel)

        subtitleLabel.maximumNumberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingMiddle
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.isHidden = true
        addSubview(subtitleLabel)
    }

    override func layout() {
        super.layout()
        imageView.fitSize().setX(3).centerVertically()
        titleLabel.setX(imageView.frame.maxX + 4).extendToRight(0).fitHeight()
        if subtitleLabel.isVisible {
            subtitleLabel.setX(titleLabel.frame.minX).extendToRight(0).fitHeight().setY(titleLabel.frame.maxY + subtitleMarginTop)
        }
        ([titleLabel, subtitleLabel] as [NSView]).visibleViews.centerGroupVertically()
    }

    override func sizeThatFits(_ size: NSSize) -> NSSize {
        let imageHeight = imageView.image?.size.height ?? 0
        var textHeight = titleLabel.sizeThatFits(.max).height
        if subtitleLabel.isVisible {
            textHeight += subtitleLabel.sizeThatFits(.max).height + subtitleMarginTop
        }
        var result = size
        result.height = max(imageHeight, textHeight)
        return result
    }

    override func sizeToFit() {
        setSize(sizeThatFits(.max))
    }
}
