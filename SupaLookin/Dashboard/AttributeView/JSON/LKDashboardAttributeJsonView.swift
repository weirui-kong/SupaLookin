//
//  LKDashboardAttributeJsonView.swift
//  SupaLookin
//
//  Created by likai.123 on 2023/11/30.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKDashboardAttributeJsonView: LKDashboardAttributeView {

    private let contentView = LKJSONAttributeContentView(bigFont: false)

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.cornerRadius = DashboardCardControlCornerRadius

        contentView.didReloadData = { [weak self] in
            self?.dashboardViewController?.view.needsLayout = true
        }
        addSubview(contentView)
    }

    override func layout() {
        super.layout()
        contentView.fillSuperview()
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        size.height = contentView.queryContentHeight()
        return size
    }

    override func renderWithAttribute() {
        super.renderWithAttribute()
        guard let json = attribute?.value as? String else {
            contentView.render(withJSON: nil)
            assertionFailure()
            return
        }
        contentView.render(withJSON: json)
    }

    func showInNewWindow() {
        guard let json = attribute?.value as? String else {
            assertionFailure()
            return
        }
        LKNavigationManager.sharedInstance.showJsonWindow(json)
    }
}
