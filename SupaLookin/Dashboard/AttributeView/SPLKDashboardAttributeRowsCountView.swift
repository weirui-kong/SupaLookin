//
//  SPLKDashboardAttributeRowsCountView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/12.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import SPLKServer

final class SPLKDashboardAttributeRowsCountView: SPLKDashboardAttributeView {

    private var inputsView: [SPLKNumberInputView] = []

    override func layout() {
        super.layout()
        for (idx, view) in inputsView.enumerated() {
            let y = CGFloat(idx) * (SPLKNumberInputHorizontalHeight + DashboardAttrItemVerInterspace)
            view.fillWidth().setHeight(SPLKNumberInputHorizontalHeight).setY(y)
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        let height = (SPLKNumberInputHorizontalHeight + DashboardAttrItemVerInterspace) * CGFloat(inputsView.count) - DashboardAttrItemVerInterspace
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
            let view = SPLKNumberInputView()
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
