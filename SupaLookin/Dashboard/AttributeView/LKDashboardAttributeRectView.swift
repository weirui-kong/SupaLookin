//
//  LKDashboardAttributeRectView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/10.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKDashboardAttributeRectView: LKDashboardAttributeView, NSTextFieldDelegate {

    private var mainInputsView: [LKNumberInputView] = []

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let titles = ["X", "Y", "W", "H"]
        mainInputsView = titles.map { title in
            let view = LKNumberInputView()
            view.title = title
            view.viewStyle = .horizontal
            view.textFieldView.textField.delegate = self
            view.textFieldView.backgroundColorName = "DashboardCardValueBGColor"
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
        let rect = value.rectValue
        let mainStrs = [NSString.lookin_string(from: rect.origin.x, decimal: 3) ?? "",
                        NSString.lookin_string(from: rect.origin.y, decimal: 3) ?? "",
                        NSString.lookin_string(from: rect.size.width, decimal: 3) ?? "",
                        NSString.lookin_string(from: rect.size.height, decimal: 3) ?? ""]

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

        var expectedRect = (attribute.value as? NSValue)?.rectValue ?? .zero
        switch editingTextFieldIdx {
        case 0:
            // x
            expectedRect.origin.x = inputDouble
        case 1:
            // y
            expectedRect.origin.y = inputDouble
        case 2:
            // width
            expectedRect.size.width = inputDouble
        case 3:
            // height
            expectedRect.size.height = inputDouble
        default:
            renderWithAttribute()
            assertionFailure()
        }

        let expectedValue = NSValue(rect: expectedRect)
        if expectedValue.isEqual(attribute.value) {
            NSLog("修改没有变化，不做任何提交")
            renderWithAttribute()
            return
        }
        // 提交修改
        let oldRect = (attribute.value as? NSValue)?.rectValue ?? .zero

        guard let dashboardViewController else { return }
        Task { [weak self] in
            do {
                try await dashboardViewController.modifyAttribute(attribute, newValue: expectedValue)
                guard let self else { return }
                let currentRect = (self.attribute?.value as? NSValue)?.rectValue ?? .zero
                if self.rect(oldRect, isAlmostEqualTo: currentRect) && !self.rect(expectedRect, isAlmostEqualTo: currentRect) {
                    // Lookin 更改了 value 之后，又被 iOS 里的业务改回去了，这个在修改 frame 时经常出现，就像 Lookin 更改失败了一样，为了避免用户迷惑，这里特意弹窗告知一下
                    LKHelper.alertErrorText(NSLocalizedString("The modification seems to have no effect.", comment: ""), NSLocalizedString("After modifying successfully by Lookin, the value seems to be recovered by the code in your iOS app. For example, modifying \"frame\" of a view may trigger \"layoutSubviews\", and \"layoutSubviews\" may modify the value again.", comment: ""), window: self.window)
                }
            } catch {
                NSLog("修改返回 error")
                self?.renderWithAttribute()
            }
        }
    }

    private func rect(_ rectA: CGRect, isAlmostEqualTo rectB: CGRect) -> Bool {
        if abs(rectA.origin.x - rectB.origin.x) > 0.1 {
            return false
        }
        if abs(rectA.origin.y - rectB.origin.y) > 0.1 {
            return false
        }
        if abs(rectA.size.width - rectB.size.width) > 0.1 {
            return false
        }
        if abs(rectA.size.height - rectB.size.height) > 0.1 {
            return false
        }
        return true
    }
}
