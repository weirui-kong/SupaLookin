//
//  LKLaunchAppView.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/3.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKLaunchAppView: LKBaseControl {

    private let hoverBgLayer = CALayer()
    private let previewImageView = NSImageView()
    private let iconImageView = NSImageView()
    private let titleLabel = LKLabel()
    private let subtitleLabel = LKLabel()
    private var errorImageView: NSImageView?
    private var errorTitleLabel: LKLabel?
    private var errorSubtitleLabel: LKLabel?

    private var previewSize = NSSize.zero
    private var insets = NSEdgeInsets()
    private var iconTop: CGFloat = 0
    private var iconMarginRight: CGFloat = 0

    /// 默认为 false
    var compactLayout = false {
        didSet {
            applyCompactLayout()
        }
    }

    var app: LKInspectableApp? {
        didSet {
            updateApp()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.cornerRadius = 4

        hoverBgLayer.opacity = 0
        hoverBgLayer.cornerRadius = 4
        layer?.addSublayer(hoverBgLayer)

        addSubview(previewImageView)
        addSubview(iconImageView)

        titleLabel.textColor = .labelColor
        addSubview(titleLabel)

        subtitleLabel.textColor = .labelColor
        addSubview(subtitleLabel)

        applyCompactLayout()
    }

    private func applyCompactLayout() {
        if compactLayout {
            previewSize = NSSize(width: 120, height: 220)
            insets = NSEdgeInsets(top: 12, left: 13, bottom: 8, right: 13)
            iconTop = 10
            iconMarginRight = 6
            titleLabel.font = .systemFont(ofSize: 12)
            subtitleLabel.font = .systemFont(ofSize: 11)
        } else {
            previewSize = NSSize(width: 142, height: 260)
            insets = NSEdgeInsets(top: 12, left: 25, bottom: 12, right: 25)
            iconTop = 10
            iconMarginRight = 8
            titleLabel.font = .systemFont(ofSize: 13)
            subtitleLabel.font = .systemFont(ofSize: 12)
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()

        hoverBgLayer.frame = layer?.bounds ?? .zero

        if app?.serverVersionError != nil, let errorImageView, let errorTitleLabel, let errorSubtitleLabel {
            errorImageView.fitSize().centerHorizontally()
            errorTitleLabel.setX(10).extendToRight(10).fitHeight().setY(errorImageView.frame.maxY + 15)
            errorSubtitleLabel.fitSize().centerHorizontally().setY(errorTitleLabel.frame.maxY + 10)
            let group: [NSView] = [errorImageView, errorTitleLabel, errorSubtitleLabel]
            group.centerGroupVertically()
            group.offset(y: -10)
        } else {
            previewImageView.setSize(previewSize).centerHorizontally().setY(insets.top)

            iconImageView.fitSize().setY(insets.top + previewSize.height + iconTop)

            titleLabel.fitSize()
            subtitleLabel.fitSize().setY(titleLabel.frame.maxY + 2)
            let labels: [NSView] = [titleLabel, subtitleLabel]
            labels.forEach { $0.setX(iconImageView.frame.maxX + iconMarginRight) }
            labels.setGroupMidY(iconImageView.frame.midY)

            let group: [NSView] = [iconImageView, titleLabel, subtitleLabel]
            group.centerGroupHorizontally()
            group.offset(x: -2)
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        if app?.serverVersionError != nil {
            return NSSize(width: previewSize.width + insets.left + insets.right, height: insets.top + previewSize.height + iconTop + insets.bottom)
        }
        let iconSize = iconImageView.image?.size ?? .zero
        let previewWidth = previewSize.width + insets.left + insets.right
        let labelsWidth = iconSize.width + iconMarginRight + max(titleLabel.sizeThatFits(.max).width, subtitleLabel.sizeThatFits(.max).width) + insets.left + insets.right

        let width = max(previewWidth, labelsWidth)
        let height = insets.top + previewSize.height + iconTop + iconSize.height + insets.bottom
        return NSSize(width: width, height: height)
    }

    override func sizeToFit() {
        setFrameSize(sizeThatFits(.max))
    }

    private func updateApp() {
        if let serverVersionError = app?.serverVersionError {
            initErrorViewsIfNeeded()

            errorImageView?.isHidden = false
            errorTitleLabel?.isHidden = false
            errorSubtitleLabel?.isHidden = false

            previewImageView.isHidden = true
            iconImageView.isHidden = true
            titleLabel.isHidden = true
            subtitleLabel.isHidden = true

            if serverVersionError.code == LookinErrCode_ServerVersionTooLow {
                errorTitleLabel?.stringValue = NSLocalizedString("The version of LookinServer linked with this iOS App is too low.", comment: "")
            } else if serverVersionError.code == LookinErrCode_ServerVersionTooHigh {
                errorTitleLabel?.stringValue = NSLocalizedString("Unable to inspect this iOS App. Current version of Lookin app is too low.", comment: "")
            } else {
                errorTitleLabel?.stringValue = "Unknown Error"
                assertionFailure()
            }
        } else {
            errorImageView?.isHidden = true
            errorTitleLabel?.isHidden = true
            errorSubtitleLabel?.isHidden = true

            previewImageView.isHidden = false
            iconImageView.isHidden = false
            titleLabel.isHidden = false
            subtitleLabel.isHidden = false

            let appInfo = app?.appInfo
            previewImageView.image = appInfo?.screenshot
            switch appInfo?.deviceType {
            case .simulator:
                iconImageView.image = NSImage(named: "icon_simulator_big")
            case .iPad:
                iconImageView.image = NSImage(named: "icon_ipad_big")
            default:
                iconImageView.image = NSImage(named: "icon_iphone_big")
            }
            titleLabel.stringValue = appInfo?.deviceDescription ?? ""
            subtitleLabel.stringValue = "iOS \(appInfo?.osDescription ?? "(null)")"
        }

        updateLayer()
        needsLayout = true
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        hoverBgLayer.opacity = 1
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hoverBgLayer.opacity = 0
    }

    override func updateLayer() {
        super.updateLayer()
        let isDarkMode = effectiveAppearance.isDarkMode
        hoverBgLayer.backgroundColor = isDarkMode ? NSColor(lookinRed: 0, green: 0, blue: 0, alpha: 0.17).cgColor : NSColor(lookinRed: 0, green: 0, blue: 0, alpha: 0.08).cgColor

        if app?.serverVersionError != nil {
            layer?.backgroundColor = isDarkMode ? NSColor(lookinRed: 0, green: 0, blue: 0, alpha: 0.13).cgColor : NSColor(lookinRed: 0, green: 0, blue: 0, alpha: 0.05).cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let newArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(newArea)
    }

    private func initErrorViewsIfNeeded() {
        if errorImageView == nil {
            let imageView = NSImageView()
            imageView.image = NSImage(named: "icon_alert_big")
            addSubview(imageView)
            errorImageView = imageView
        }
        if errorTitleLabel == nil {
            let label = LKLabel()
            label.textColor = .labelColor
            label.alignment = .center
            label.maximumNumberOfLines = 0
            addSubview(label)
            errorTitleLabel = label
        }
        if errorSubtitleLabel == nil {
            let label = LKLabel()
            label.stringValue = NSLocalizedString("Find solution…", comment: "")
            label.textColor = .linkColor
            addSubview(label)
            errorSubtitleLabel = label
        }
    }
}
