//
//  SPLKDashboardAccessoryWindowController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/8/30.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import SPLKServer

protocol SPLKDashboardAccessoryWindowControllerDelegate: AnyObject {
    func dashboardAccessoryWindowControllerWillClose(_ controller: SPLKDashboardAccessoryWindowController)
}

final class SPLKDashboardAccessoryWindowController: SPLKWindowController, NSWindowDelegate {

    weak var delegate: SPLKDashboardAccessoryWindowControllerDelegate?

    private let groupID: String
    private weak var dashboardController: SPLKDashboardViewController?
    private var sectionViews: [String: SPLKDashboardSectionView] = [:]

    init(dashboardController: SPLKDashboardViewController?, attrGroupID groupID: String) {
        self.groupID = groupID
        self.dashboardController = dashboardController

        let panel = SPLKPopPanel(size: NSSize(width: 400, height: 100))
        super.init(window: panel)
        panel.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(withAttrSections sections: [SPLKAttributesSection]) -> NSSize {
        var needlessViews = Array(sectionViews.values)

        for (idx, attrSec) in sections.enumerated() {
            let view: SPLKDashboardSectionView
            if let existing = sectionViews[attrSec.identifier] {
                view = existing
                needlessViews.removeAll { $0 === view }
                view.isHidden = false
            } else {
                view = SPLKDashboardSectionView()
                sectionViews[attrSec.identifier] = view
            }

            view.dashboardViewController = dashboardController
            view.manageState = .canAdd
            view.attrSection = attrSec
            view.showTopSeparator = idx != 0
            window?.contentView?.addSubview(view)
        }

        needlessViews.forEach { $0.isHidden = true }

        // layout
        let normalSecWidth = DashboardViewWidth - DashboardHorInset * 2
        var y: CGFloat = 8
        for secID in SPLKDashboardBlueprint.sectionIDs(forGroupID: groupID) ?? [] {
            guard let view = sectionViews[secID], !view.isHidden else {
                continue
            }
            view.setX(DashboardHorInset).setWidth(normalSecWidth - DashboardHorInset * 2).fitHeight().setY(y)
            y = view.frame.maxY + DashboardSectionMarginTop
        }

        return NSSize(width: normalSecWidth + 23, height: y)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        delegate?.dashboardAccessoryWindowControllerWillClose(self)
    }
}
