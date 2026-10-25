//
//  LKTutorialPopoverController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/7/17.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKTutorialPopoverController: LKBaseViewController {

    private var imageView: NSImageView!
    private var label: LKLabel!
    private var closeButton: NSButton!
    private weak var popover: NSPopover?

    private let insets = NSEdgeInsets(top: 12, left: 8, bottom: 10, right: 8)
    private let labelMarginLeft: CGFloat = 5

    var showTimestamp: TimeInterval = 0
    private(set) var hasClickedCloseButton = false
    var learnedBlock: (() -> Void)?

    init(text: String, popover: NSPopover) {
        super.init(containerView: nil)
        label.stringValue = text
        self.popover = popover
    }

    override func makeContainerView() -> NSView {
        let containerView = super.makeContainerView()

        imageView = NSImageView()
        imageView.image = NSImage(named: "Icon_Inspiration")
        containerView.addSubview(imageView)

        label = LKLabel()
        label.font = .systemFont(ofSize: 13)
        containerView.addSubview(label)
        closeButton = NSButton.normalButton(title: NSLocalizedString("Do not show again", comment: "")) { [unowned self] _ in
            self.hasClickedCloseButton = true
            self.popover?.close()
        }
        containerView.addSubview(closeButton)

        return containerView
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        imageView.fitSize().setX(insets.left)
        label.setX(imageView.frame.maxX + labelMarginLeft).extendToRight(insets.right).fitHeight().setY(insets.top)
        imageView.setMidY(label.frame.midY - 1)
        closeButton.fitSize().centerHorizontally().alignBottom(insets.bottom)
    }

    func contentSize() -> NSSize {
        let imageWidth = imageView.image?.size.width ?? 0
        let maxWidth: CGFloat = 400
        let labelMaxWidth = maxWidth - imageWidth - insets.left - insets.right - labelMarginLeft
        let labelSize = label.sizeThatFits(NSSize(width: labelMaxWidth, height: .greatestFiniteMagnitude))

        return NSSize(width: imageWidth + insets.left + insets.right + labelSize.width + labelMarginLeft, height: labelSize.height + 60)
    }
}
