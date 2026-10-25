//
//  LKPanelContentView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/24.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

class LKPanelContentView: LKBaseView {

    private let titleImageView = NSImageView()
    private let titleLabel = LKLabel()
    private let titleContainerView = LKBaseView()
    private var cancelButton: NSButton!
    private(set) var submitButton: NSButton!

    let contentView = LKBaseView()

    var titleImage: NSImage? {
        didSet {
            titleImageView.image = titleImage
            needsLayout = true
        }
    }

    var titleText: String? {
        didSet {
            titleLabel.stringValue = titleText ?? ""
            needsLayout = true
        }
    }

    var needExit: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColorName = "DashboardBackgroundColor"

        titleContainerView.backgroundColorName = "PanelTitleBackgroundColor"
        addSubview(titleContainerView)

        titleContainerView.addSubview(titleImageView)

        titleLabel.font = .systemFont(ofSize: 13)
        titleContainerView.addSubview(titleLabel)

        cancelButton = NSButton.normalButton(title: NSLocalizedString("Cancel", comment: "")) { [weak self] _ in
            self?.needExit?()
        }
        // esc
        cancelButton.keyEquivalent = "\u{1b}"
        addSubview(cancelButton)

        submitButton = NSButton.normalButton(title: NSLocalizedString("Done", comment: "")) { [weak self] _ in
            self?.didClickSubmitButton()
        }
        submitButton.keyEquivalent = "\r"
        addSubview(submitButton)

        contentView.layer?.masksToBounds = false
        addSubview(contentView)
    }

    override func layout() {
        super.layout()

        let insets = NSEdgeInsets(top: 0, left: 14, bottom: 6, right: 14)

        titleContainerView.fillWidth().setHeight(40).setY(0)
        titleImageView.fitSize().setX(insets.left).centerVertically()
        titleLabel.fitSize().setX(titleImageView.frame.maxX + 6).centerVertically()

        submitButton.alignRight(insets.right).alignBottom(insets.bottom)
        cancelButton.setMaxX(submitButton.frame.minX - 5).alignBottom(insets.bottom)

        contentView.setX(insets.left).extendToRight(insets.right).setY(titleContainerView.frame.maxY + 10).extendToMaxY(submitButton.frame.minY - 10)
    }

    // MARK: - Subclassing hooks

    func didClickSubmitButton() {
        assertionFailure("should implement by subclass")
    }
}
