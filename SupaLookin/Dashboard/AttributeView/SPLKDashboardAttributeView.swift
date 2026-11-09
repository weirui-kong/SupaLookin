//
//  SPLKDashboardAttributeView.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/18.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import SPLKServer

class SPLKDashboardAttributeView: SPLKBaseView {

    var attribute: SPLKAttribute? {
        didSet {
            renderWithAttribute()
        }
    }

    var valueView: Any?

    weak var dashboardViewController: SPLKDashboardViewController? {
        didSet {
            dashboardViewControllerDidChange()
        }
    }

    // The section view creates attribute views from their class.
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    func canEdit() -> Bool {
        guard let attribute else {
            return false
        }
        if attribute.isUserCustom() {
            return (attribute.customSetterID?.isEmpty == false)
        }
        let setter = SPLKDashboardBlueprint.setter(withAttrID: attribute.identifier)
        return setter != nil && (dashboardViewController?.isStaticMode ?? false)
    }

    /// 提交修改，失败时重新渲染当前值
    func submitModification(_ newValue: Any?) {
        guard let attribute, let dashboardViewController else {
            return
        }
        Task { [weak self] in
            do {
                try await dashboardViewController.modifyAttribute(attribute, newValue: newValue)
            } catch {
                NSLog("修改返回 error")
                self?.renderWithAttribute()
            }
        }
    }

    // MARK: - Subclassing hooks

    func renderWithAttribute() {
        // do nothing
    }

    var numberOfColumnsOccupied: Int {
        1
    }

    func dashboardViewControllerDidChange() {
    }
}
