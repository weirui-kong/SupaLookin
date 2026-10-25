//
//  LKDashboardSearchCardView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/9/5.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

class LKDashboardSearchCardView: LKBaseView {

    private let backgroundEffectView = LKVisualEffectView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.cornerRadius = DashboardCardCornerRadius

        backgroundEffectView.blendingMode = .withinWindow
        backgroundEffectView.state = .active
        addSubview(backgroundEffectView)
    }

    override func layout() {
        super.layout()
        backgroundEffectView.fillSuperview()
    }
}
