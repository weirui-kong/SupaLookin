//
//  LKDashboardCardTitleControl.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/4/13.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKDashboardCardTitleControl: LKBaseControl {

    let iconImageView = NSImageView()
    let label = LKLabel()
    let disclosureImageView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(iconImageView)

        label.textColor = .labelColor
        label.font = .systemFont(ofSize: 13)
        addSubview(label)

        addSubview(disclosureImageView)
    }

    override func layout() {
        super.layout()

        iconImageView.fitSize().centerVertically().setX(DashboardHorInset).offset(y: -1)
        label.fitSize().centerVertically().offset(y: -1).setX(iconImageView.frame.maxX + 3)
        disclosureImageView.fitSize().centerVertically().setX(label.frame.maxX + 3)
    }
}
