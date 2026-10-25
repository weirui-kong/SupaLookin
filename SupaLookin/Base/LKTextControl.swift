//
//  LKTextControl.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/3/12.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

class LKTextControl: LKBaseControl {

    let label = LKLabel()

    private var rightImageView: NSImageView?

    var insets = NSEdgeInsets() {
        didSet {
            needsLayout = true
        }
    }

    var rightImage: NSImage? {
        didSet {
            if let rightImage {
                if rightImageView == nil {
                    let imageView = NSImageView()
                    addSubview(imageView)
                    rightImageView = imageView
                }
                rightImageView?.image = rightImage
            } else {
                rightImageView?.removeFromSuperview()
            }
            needsLayout = true
        }
    }

    var spaceBetweenLabelAndImage: CGFloat = 0 {
        didSet {
            needsLayout = true
        }
    }

    var rightImageOffsetY: CGFloat = 0 {
        didSet {
            needsLayout = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.alignment = .center
        addSubview(label)
    }

    override func layout() {
        super.layout()
        var labelMaxX = frame.width - insets.right
        if let rightImageView {
            rightImageView.fitSize().centerVertically().alignRight(insets.right).offset(y: rightImageOffsetY)
            labelMaxX = rightImageView.frame.minX - spaceBetweenLabelAndImage
        }
        label.setX(insets.left).extendToMaxX(labelMaxX).fitHeight().centerVertically()
        if insets.top != insets.bottom {
            label.offset(y: insets.top - insets.bottom)
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        // Messaging a nil rightImageView in Objective-C read as "not hidden" and a zero width, which this keeps.
        let showsRightImage = !(rightImageView?.isHidden ?? false)
        let rightImageWidth = rightImageView?.bestWidth ?? 0

        var labelMaxWidth = limitedSize.width - insets.left - insets.right
        if showsRightImage {
            labelMaxWidth -= rightImageWidth + spaceBetweenLabelAndImage
        }

        let labelSize = label.sizeThatFits(NSSize(width: labelMaxWidth, height: .greatestFiniteMagnitude))

        var resultWidth = labelSize.width + insets.left + insets.right
        if showsRightImage {
            resultWidth += rightImageWidth + spaceBetweenLabelAndImage
        }
        let resultHeight = labelSize.height + insets.top + insets.bottom
        return NSSize(width: resultWidth, height: resultHeight)
    }
}
