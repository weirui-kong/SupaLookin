//
//  LKDashboardAttributePointView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/11.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKDashboardAttributePointView: LKDashboardAttributeView, NSTextFieldDelegate {

    private var inputsView: [LKNumberInputView] = []

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let titles = ["X", "Y"]
        inputsView = titles.map { title in
            let view = LKNumberInputView()
            view.title = title
            view.viewStyle = .horizontal
            view.textFieldView.textField.delegate = self
            addSubview(view)
            return view
        }
    }

    override func layout() {
        super.layout()
        let itemWidth = (frame.width - DashboardAttrItemHorInterspace) / 2.0
        for (idx, view) in inputsView.enumerated() {
            let x = idx > 0 ? (itemWidth + DashboardAttrItemHorInterspace) : 0
            view.setWidth(itemWidth).setHeight(LKNumberInputHorizontalHeight).setX(x).setY(0)
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        size.height = LKNumberInputHorizontalHeight
        return size
    }

    override func renderWithAttribute() {
        guard let attribute else { return }
        guard let value = attribute.value as? NSValue else {
            assertionFailure()
            return
        }
        let current = value.pointValue
        let mainStrs = [NSString.lookin_string(from: current.x, decimal: 3) ?? "", NSString.lookin_string(from: current.y, decimal: 3) ?? ""]

        for (idx, view) in inputsView.enumerated() {
            view.textFieldView.textField.isEditable = canEdit()
            view.textFieldView.textField.stringValue = mainStrs[idx]
        }
    }

    // MARK: - NSTextFieldDelegate

    func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
        canEdit()
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        if LKDashboardTextControlEditingFlag.sharedInstance.shouldIgnoreTextEditingChangeEvent {
            NSLog("忽略 controlTextDidEndEditing 事件，驳回")
            return
        }
        guard let attribute, let editingTextField = notification.object as? NSTextField else { return }
        guard let inputValue = LKNumberInputView.parsedValue(with: editingTextField.stringValue, attrType: .double) else {
            NSLog("输入格式校验不通过，驳回")
            renderWithAttribute()
            return
        }

        let inputDouble = inputValue.doubleValue
        let editingTextFieldIdx = inputsView.firstIndex { $0.textFieldView.textField === editingTextField }

        var expected = (attribute.value as? NSValue)?.pointValue ?? .zero
        switch editingTextFieldIdx {
        case 0:
            // x
            expected.x = inputDouble
        case 1:
            // y
            expected.y = inputDouble
        default:
            renderWithAttribute()
            assertionFailure()
        }

        let expectedValue = NSValue(point: expected)
        if expectedValue.isEqual(attribute.value) {
            NSLog("修改没有变化，不做任何提交")
            renderWithAttribute()
            return
        }

        // 提交修改
        submitModification(expectedValue)
    }

    // MARK: - Others

    override func dashboardViewControllerDidChange() {
        super.dashboardViewControllerDidChange()
        for view in inputsView {
            view.textFieldView.backgroundColorName = "DashboardCardValueBGColor"
        }
    }
}
