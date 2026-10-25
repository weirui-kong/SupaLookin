//
//  LKDashboardAttributeInsetsView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/10.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKDashboardAttributeInsetsView: LKDashboardAttributeView, NSTextFieldDelegate {

    private var mainInputsView: [LKNumberInputView] = []

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let titles = ["T", "L", "B", "R"]
        mainInputsView = titles.map { title in
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
        for (idx, view) in mainInputsView.enumerated() {
            let x: CGFloat = (idx == 0 || idx == 2) ? 0 : itemWidth + DashboardAttrItemHorInterspace
            let y: CGFloat = (idx == 0 || idx == 1) ? 0 : LKNumberInputHorizontalHeight + DashboardAttrItemVerInterspace
            view.setWidth(itemWidth).setHeight(LKNumberInputHorizontalHeight).setX(x).setY(y)
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        size.height = LKNumberInputHorizontalHeight * 2 + DashboardAttrItemVerInterspace
        return size
    }

    override func renderWithAttribute() {
        guard let attribute else {
            assertionFailure()
            return
        }
        guard let value = attribute.value as? NSValue else {
            assertionFailure()
            return
        }
        let insets = value.edgeInsetsValue
        let mainStrs = [NSString.lookin_string(from: insets.top, decimal: 3) ?? "",
                        NSString.lookin_string(from: insets.left, decimal: 3) ?? "",
                        NSString.lookin_string(from: insets.bottom, decimal: 3) ?? "",
                        NSString.lookin_string(from: insets.right, decimal: 3) ?? ""]

        for (idx, view) in mainInputsView.enumerated() {
            view.textFieldView.textField.isEditable = canEdit()
            view.textFieldView.textField.stringValue = mainStrs[idx]
        }
    }

    // MARK: - NSTextFieldDelegate

    func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
        canEdit()
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        if !canEdit() {
            return
        }
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
        let editingTextFieldIdx = mainInputsView.firstIndex { $0.textFieldView.textField === editingTextField }

        let originInsets = (attribute.value as? NSValue)?.edgeInsetsValue ?? NSEdgeInsets()
        var expectedInsets = originInsets
        switch editingTextFieldIdx {
        case 0:
            // top
            expectedInsets.top = inputDouble
        case 1:
            // left
            expectedInsets.left = inputDouble
        case 2:
            // bottom
            expectedInsets.bottom = inputDouble
        case 3:
            // right
            expectedInsets.right = inputDouble
        default:
            renderWithAttribute()
            assertionFailure()
        }

        // 这里 NSValue 的 isEqual: 方法不准，要手动判断
        let valueDidChange = originInsets.top != expectedInsets.top ||
            originInsets.left != expectedInsets.left ||
            originInsets.bottom != expectedInsets.bottom ||
            originInsets.right != expectedInsets.right
        if !valueDidChange {
            NSLog("修改没有变化，不做任何提交")
            renderWithAttribute()
            return
        }
        let expectedValue = NSValue(edgeInsets: expectedInsets)

        // 提交修改
        submitModification(expectedValue)
    }

    // MARK: - Others

    override func dashboardViewControllerDidChange() {
        super.dashboardViewControllerDidChange()
        for view in mainInputsView {
            view.textFieldView.backgroundColorName = "DashboardCardValueBGColor"
        }
    }
}
