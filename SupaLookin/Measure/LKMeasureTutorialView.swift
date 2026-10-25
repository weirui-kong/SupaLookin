//
//  LKMeasureTutorialView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/10/21.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKMeasureTutorialView: LKBaseView {

    private let imageView = NSImageView()
    private let titleLabel = LKLabel()
    private let subtitleLabel = LKLabel()

    private let insets = NSEdgeInsets(top: 15, left: 5, bottom: 12, right: 5)
    private let titleTop: CGFloat = 11
    private let subtitleTop: CGFloat = 6

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        hasEffectedBackground = true
        layer?.cornerRadius = DashboardCardCornerRadius

        addSubview(imageView)

        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.alignment = .center
        addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.alignment = .center
        addSubview(subtitleLabel)
    }

    func render(withImage image: NSImage?, title: String, subtitle: String) {
        imageView.image = image
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        needsLayout = true
    }

    override func layout() {
        super.layout()
        imageView.fitSize().centerHorizontally().setY(insets.top)
        titleLabel.fitSize().centerHorizontally().setY(imageView.frame.maxY + titleTop)
        subtitleLabel.setX(insets.left).extendToRight(insets.right).fitHeight().setY(titleLabel.frame.maxY + subtitleTop)
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        let contentWidth = limitedSize.width - insets.left - insets.right
        var resultHeight = insets.top + insets.bottom
        resultHeight += imageView.bestHeight
        resultHeight += titleTop
        resultHeight += titleLabel.height(forWidth: contentWidth)
        resultHeight += subtitleTop
        resultHeight += subtitleLabel.height(forWidth: contentWidth)
        var size = limitedSize
        size.height = resultHeight
        return size
    }
}
