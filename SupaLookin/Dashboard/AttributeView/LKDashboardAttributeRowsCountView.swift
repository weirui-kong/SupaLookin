//
//  LKDashboardAttributeRowsCountView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/12.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKDashboardAttributeRowsCountView: LKDashboardAttributeView {

    private var inputsView: [LKNumberInputView] = []

    override func layout() {
        super.layout()
        for (idx, view) in inputsView.enumerated() {
            let y = CGFloat(idx) * (LKNumberInputHorizontalHeight + DashboardAttrItemVerInterspace)
            view.fillWidth().setHeight(LKNumberInputHorizontalHeight).setY(y)
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        let height = (LKNumberInputHorizontalHeight + DashboardAttrItemVerInterspace) * CGFloat(inputsView.count) - DashboardAttrItemVerInterspace
        var size = limitedSize
        size.height = max(height, 0)
        return size
    }

    override func renderWithAttribute() {
        guard let attribute else {
            assertionFailure()
            return
        }
        guard let numbers = attribute.value as? [NSNumber] else {
            assertionFailure()
            return
        }

        inputsView = inputsView.resized(count: numbers.count, add: { _ in
            let view = LKNumberInputView()
            view.textFieldView.textField.isEditable = false
            view.viewStyle = .horizontal
            view.textFieldView.backgroundColorName = "DashboardCardValueBGColor"
            self.addSubview(view)
            return view
        }, remove: { _, view in
            view.removeFromSuperview()
        }, doNext: { idx, view in
            view.title = "Section \(idx)"
            view.textFieldView.textField.stringValue = "\(numbers[idx])"
        })

        needsLayout = true
    }

    // MARK: - Others

    override func dashboardViewControllerDidChange() {
        super.dashboardViewControllerDidChange()
        for view in inputsView {
            view.textFieldView.backgroundColorName = "DashboardCardValueBGColor"
        }
    }
}
