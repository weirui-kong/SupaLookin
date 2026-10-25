//
//  LKDashboardAttributeNumberInputView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/2/21.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

private let horizontalAttrs: [String] = [
    LookinAttr_ViewLayer_Visibility_Opacity,
    LookinAttr_ViewLayer_Corner_Radius,
    LookinAttr_ViewLayer_Tag_Tag,
    LookinAttr_UILabel_Font_Size,
    LookinAttr_UILabel_NumberOfLines_NumberOfLines,
    LookinAttr_UITextView_Font_Size,
    LookinAttr_UITextField_Font_Size,
    LookinAttr_UITextField_CanAdjustFont_MinSize,
    LookinAttr_ViewLayer_Border_Width,
    LookinAttr_UITableView_SectionsNumber_Number,
    LookinAttr_AutoLayout_Resistance_Ver,
    LookinAttr_AutoLayout_Resistance_Hor,
    LookinAttr_AutoLayout_Hugging_Ver,
    LookinAttr_AutoLayout_Hugging_Hor,
    LookinAttr_UIStackView_Spacing_Spacing,
]

private let columnsDict: [String: Int] = [
    LookinAttr_ViewLayer_Visibility_Opacity: 1,
    LookinAttr_ViewLayer_Corner_Radius: 1,
    LookinAttr_ViewLayer_Tag_Tag: 1,
    LookinAttr_UITextView_Font_Size: 1,
    LookinAttr_UITextField_Font_Size: 1,
    LookinAttr_UITextField_CanAdjustFont_MinSize: 1,
    LookinAttr_ViewLayer_Border_Width: 1,
    LookinAttr_UITableView_SectionsNumber_Number: 1,
    LookinAttr_UILabel_NumberOfLines_NumberOfLines: 1,
    LookinAttr_UILabel_Font_Size: 1,
    LookinAttr_UIStackView_Spacing_Spacing: 1,

    LookinAttr_AutoLayout_Resistance_Ver: 2,
    LookinAttr_AutoLayout_Resistance_Hor: 2,
    LookinAttr_AutoLayout_Hugging_Ver: 2,
    LookinAttr_AutoLayout_Hugging_Hor: 2,

    LookinAttr_UIScrollView_Zoom_Scale: 3,
    LookinAttr_UIScrollView_Zoom_MinScale: 3,
    LookinAttr_UIScrollView_Zoom_MaxScale: 3,
]

final class LKDashboardAttributeNumberInputView: LKDashboardAttributeView, NSTextFieldDelegate {

    let inputView = LKNumberInputView()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        inputView.textFieldView.textField.delegate = self
        addSubview(inputView)
    }

    override func layout() {
        super.layout()
        inputView.fillSuperview()
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        switch inputView.viewStyle {
        case .horizontal:
            size.height = LKNumberInputHorizontalHeight
        case .vertical:
            size.height = LKNumberInputVerticalHeight
        }
        return size
    }

    override func renderWithAttribute() {
        guard let attribute else { return }
        inputView.textFieldView.textField.isEditable = canEdit()

        if attribute.isUserCustom() {
            inputView.title = nil
        } else {
            inputView.title = LookinDashboardBlueprint.briefTitle(withAttrID: attribute.identifier)
        }

        let doubleValue = (attribute.value as? NSNumber)?.doubleValue ?? 0

        if attribute.isUserCustom() {
            inputView.viewStyle = .horizontal
            inputView.textFieldView.textField.stringValue = NSString.lookin_string(from: doubleValue, decimal: 6) ?? ""

        } else {
            if horizontalAttrs.contains(attribute.identifier) {
                inputView.viewStyle = .horizontal
                inputView.textFieldView.textField.stringValue = NSString.lookin_string(from: doubleValue, decimal: 3) ?? ""
            } else {
                inputView.viewStyle = .vertical
                inputView.textFieldView.textField.stringValue = NSString.lookin_string(from: doubleValue, decimal: 2) ?? ""
            }
        }
    }

    override var numberOfColumnsOccupied: Int {
        guard let attribute else { return 4 }
        if attribute.isUserCustom() {
            return 1
        }
        return columnsDict[attribute.identifier] ?? 4
    }

    // MARK: - NSTextFieldDelegate

    func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
        canEdit()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if LKDashboardTextControlEditingFlag.sharedInstance.shouldIgnoreTextEditingChangeEvent {
            NSLog("忽略 controlTextDidEndEditing 事件，驳回")
            return
        }
        guard let attribute else { return }
        guard var expectedValue = LKNumberInputView.parsedValue(with: inputView.textFieldView.textField.stringValue, attrType: attribute.attrType) else {
            NSLog("输入格式校验不通过，驳回")
            renderWithAttribute()
            return
        }

        if attribute.identifier == LookinAttr_ViewLayer_Visibility_Opacity || attribute.identifier == LookinAttr_ViewLayer_Shadow_Opacity {
            let inputValue = max(min(expectedValue.doubleValue, 1), 0)
            expectedValue = NSNumber(value: inputValue)
        }

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
        inputView.textFieldView.backgroundColorName = "DashboardCardValueBGColor"
    }
}
