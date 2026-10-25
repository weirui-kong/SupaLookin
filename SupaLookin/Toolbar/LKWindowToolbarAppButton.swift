//
//  LKWindowToolbarAppButton.swift
//  SupaLookin
//
//  Created by 李凯 on 2020/6/14.
//  Copyright © 2020 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKWindowToolbarAppButton: NSButton {

    private let appImageView = NSImageView()
    private let appNameLabel = LKLabel()
    private let sepImageView = NSImageView()
    private let deviceImageView = NSImageView()
    private let deviceLabel = LKLabel()
    private let appImageWidth: CGFloat = 14
    private let spaces: [CGFloat] = [7, 3, 3, 4, 1]

    var appInfo: LookinAppInfo? {
        didSet {
            updateAppInfo()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        title = ""

        appImageView.wantsLayer = true
        appImageView.layer?.cornerRadius = 2
        appImageView.layer?.masksToBounds = true
        addSubview(appImageView)

        appNameLabel.textColors = LKTwoColors(lightMode: NSColor(lookinRed: 65, green: 65, blue: 65), darkMode: .labelColor)
        addSubview(appNameLabel)

        sepImageView.image = NSImage(named: "icon_go_forward")
        sepImageView.image?.isTemplate = true
        addSubview(sepImageView)

        addSubview(deviceImageView)

        deviceLabel.textColors = LKTwoColors(lightMode: NSColor(lookinRed: 65, green: 65, blue: 65), darkMode: .labelColor)
        deviceLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(deviceLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        appImageView.setWidth(appImageWidth).setHeight(appImageWidth).setX(spaces[0]).centerVertically().offset(y: -0.5)
        appNameLabel.fitSize().centerVertically().setX(appImageView.frame.maxX + spaces[1]).offset(y: -1)
        sepImageView.fitSize().centerVertically().setX(appNameLabel.frame.maxX + spaces[2]).offset(y: -0.5)
        deviceImageView.fitSize().setX(sepImageView.frame.maxX + spaces[3]).centerVertically()
        deviceLabel.fitSize().centerVertically().setX(deviceImageView.frame.maxX + spaces[4]).extendToMaxX(frame.width).offset(y: -1)
    }

    private var subviewsToToggle: [NSView] {
        [appImageView, appNameLabel, sepImageView, deviceImageView, deviceLabel]
    }

    private func updateAppInfo() {
        if let appInfo {
            subviewsToToggle.forEach { $0.isHidden = false }
            image = nil

            appImageView.image = appInfo.appIcon ?? NSImage(named: "Icon_EmptyProject")

            appNameLabel.stringValue = appInfo.appName ?? ""

            deviceLabel.stringValue = "\(appInfo.deviceDescription ?? "(null)") (\(appInfo.osDescription ?? "(null)"))"

            switch appInfo.deviceType {
            case .simulator:
                deviceImageView.image = NSImage(named: "icon_simulator_small")
            case .iPad:
                deviceImageView.image = NSImage(named: "icon_ipad_small")
            case .others:
                deviceImageView.image = NSImage(named: "icon_iphone_small")
            default:
                deviceImageView.image = NSImage(named: "icon_simulator_small")
            }
        } else {
            subviewsToToggle.forEach { $0.isHidden = true }
            image = NSImage(named: "icon_app")
        }
        needsLayout = true
    }

    override func sizeThatFits(_ size: NSSize) -> NSSize {
        var width = spaces.reduce(0, +)
        width += appImageWidth + appNameLabel.bestWidth + sepImageView.bestWidth + deviceImageView.bestWidth + deviceLabel.bestWidth
        var result = size
        result.width = width
        return result
    }
}
