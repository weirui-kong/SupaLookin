//
//  LKOutlineRowView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/4/20.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

enum LKOutlineRowViewStatus {
    case notExpandable
    case expanded
    case collapsed
}

private let kIndentUnitWidth: CGFloat = 14
private let kDisclosureWidth: CGFloat = 16

class LKOutlineRowView: LKTableRowView {

    var imageLeft: CGFloat
    var imageRight: CGFloat
    var titleLeft: CGFloat
    var subtitleLeft: CGFloat

    private let useCompactUI: Bool

    let disclosureButton = NSButton()
    let imageView = NSImageView()

    var image: NSImage? {
        didSet {
            imageView.image = image
            imageView.isHidden = image == nil
            needsLayout = true
        }
    }

    var status: LKOutlineRowViewStatus = .notExpandable {
        didSet {
            updateDisclosureButton()
        }
    }

    var indentLevel = 0 {
        didSet {
            needsLayout = true
        }
    }

    init(compactUI compact: Bool) {
        useCompactUI = compact
        if compact {
            imageLeft = 5
            imageRight = 2
            titleLeft = 0
            subtitleLeft = 2
        } else {
            imageLeft = 5
            imageRight = 2
            titleLeft = 2
            subtitleLeft = 10
        }
        super.init(frame: .zero)

        disclosureButton.isBordered = false
        disclosureButton.setButtonType(.momentaryChange)
        addSubview(disclosureButton)

        imageView.isHidden = true
        addSubview(imageView)
    }

    convenience override init(frame frameRect: NSRect) {
        self.init(compactUI: false)
    }

    override func layout() {
        super.layout()

        disclosureButton.setWidth(kDisclosureWidth).fillHeight().setMidX(Self.disclosureMidX(withIndentLevel: indentLevel)).centerVertically()

        var x = disclosureButton.frame.maxX
        if imageView.isVisible {
            imageView.fitSize().centerVertically().setX(x + imageLeft)
            x = imageView.frame.maxX + imageRight
        }

        titleLabel.fitSize().setX(x + titleLeft).centerVertically()
        var maxX = titleLabel.frame.maxX

        if subtitleLabel.isVisible {
            subtitleLabel.fitSize().setX(titleLabel.frame.maxX + subtitleLeft).centerVertically()
            maxX = subtitleLabel.frame.maxX
        }
        [disclosureButton, titleLabel, subtitleLabel].visibleViews.offset(y: -1)

        horizontalScrollWidthManager?.rowDidLayout(withWidth: maxX)
    }

    override var isRowSelected: Bool {
        didSet {
            updateDisclosureButton()
        }
    }

    private func updateDisclosureButton() {
        switch status {
        case .notExpandable:
            disclosureButton.isHidden = true
        case .expanded:
            disclosureButton.isHidden = false
            disclosureButton.image = NSImage(named: isRowSelected ? "icon_arrow_down_selected" : "icon_arrow_down")
        case .collapsed:
            disclosureButton.isHidden = false
            disclosureButton.image = NSImage(named: isRowSelected ? "icon_arrow_right_selected" : "icon_arrow_right")
        }
    }

    static func disclosureMidX(withIndentLevel level: Int) -> CGFloat {
        insetLeft + CGFloat(level) * kIndentUnitWidth + kDisclosureWidth / 2.0
    }

    // MARK: - Subclassing hooks

    class var insetLeft: CGFloat {
        6
    }
}
