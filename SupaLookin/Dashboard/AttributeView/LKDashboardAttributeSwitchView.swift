//
//  LKDashboardAttributeSwitchView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/2/21.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKDashboardAttributeSwitchView: LKDashboardAttributeView {

    private let button = NSButton()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        button.ignoresMultiClick = true
        button.setButtonType(.switch)
        button.onAction { [unowned self] _ in
            self.handleButton()
        }
        button.font = .systemFont(ofSize: 13)
        addSubview(button)
    }

    override func layout() {
        super.layout()
        button.fillSuperview()
    }

    override func renderWithAttribute() {
        guard let attribute else { return }
        let title: String
        if attribute.isUserCustom() {
            title = attribute.displayTitle ?? ""
        } else {
            title = LookinDashboardBlueprint.briefTitle(withAttrID: attribute.identifier) ?? ""
        }
        button.attributedTitle = LKAttributedStringBuilder(title).textColor(NSColor(named: "DashboardCardValueColor") ?? .labelColor).attributedString ?? NSAttributedString()

        let boolValue = (attribute.value as? NSNumber)?.boolValue ?? false
        button.state = boolValue ? .on : .off
        button.isEnabled = canEdit()

        needsLayout = true
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        let size = button.sizeThatFits(limitedSize)
        // 不知道为什么，sizeThatFits: 返回的 size 并不够
        return NSSize(width: size.width + 3, height: size.height + 2)
    }

    override var numberOfColumnsOccupied: Int {
        if attribute?.isUserCustom() == true {
            return 1
        }
        if attribute?.identifier == LookinAttr_UIScrollView_Zoom_Bounce {
            return 1
        }
        return 0
    }

    // MARK: - Private

    private func handleButton() {
        let expectedValue: NSNumber
        switch button.state {
        case .off:
            expectedValue = NSNumber(value: false)
        case .on:
            expectedValue = NSNumber(value: true)
        default:
            assertionFailure()
            return
        }

        // 提交修改
        submitModification(expectedValue)
    }
}
