//
//  SPLKDashboardAttributeNumberInputView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/2/21.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import SPLKServer

private let horizontalAttrs: [String] = [
    SPLKAttr_ViewLayer_Visibility_Opacity,
    SPLKAttr_ViewLayer_Corner_Radius,
    SPLKAttr_ViewLayer_Tag_Tag,
    SPLKAttr_UILabel_Font_Size,
    SPLKAttr_UILabel_NumberOfLines_NumberOfLines,
    SPLKAttr_UITextView_Font_Size,
    SPLKAttr_UITextField_Font_Size,
    SPLKAttr_UITextField_CanAdjustFont_MinSize,
    SPLKAttr_ViewLayer_Border_Width,
    SPLKAttr_UITableView_SectionsNumber_Number,
    SPLKAttr_AutoLayout_Resistance_Ver,
    SPLKAttr_AutoLayout_Resistance_Hor,
    SPLKAttr_AutoLayout_Hugging_Ver,
    SPLKAttr_AutoLayout_Hugging_Hor,
    SPLKAttr_UIStackView_Spacing_Spacing,
]

private let columnsDict: [String: Int] = [
    SPLKAttr_ViewLayer_Visibility_Opacity: 1,
    SPLKAttr_ViewLayer_Corner_Radius: 1,
    SPLKAttr_ViewLayer_Tag_Tag: 1,
    SPLKAttr_UITextView_Font_Size: 1,
    SPLKAttr_UITextField_Font_Size: 1,
    SPLKAttr_UITextField_CanAdjustFont_MinSize: 1,
    SPLKAttr_ViewLayer_Border_Width: 1,
    SPLKAttr_UITableView_SectionsNumber_Number: 1,
    SPLKAttr_UILabel_NumberOfLines_NumberOfLines: 1,
    SPLKAttr_UILabel_Font_Size: 1,
    SPLKAttr_UIStackView_Spacing_Spacing: 1,

    SPLKAttr_AutoLayout_Resistance_Ver: 2,
    SPLKAttr_AutoLayout_Resistance_Hor: 2,
    SPLKAttr_AutoLayout_Hugging_Ver: 2,
    SPLKAttr_AutoLayout_Hugging_Hor: 2,

    SPLKAttr_UIScrollView_Zoom_Scale: 3,
    SPLKAttr_UIScrollView_Zoom_MinScale: 3,
    SPLKAttr_UIScrollView_Zoom_MaxScale: 3,
]

final class SPLKDashboardAttributeNumberInputView: SPLKDashboardAttributeView, NSTextFieldDelegate {

    let inputView = SPLKNumberInputView()

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
            size.height = SPLKNumberInputHorizontalHeight
        case .vertical:
            size.height = SPLKNumberInputVerticalHeight
        }
        return size
    }

    override func renderWithAttribute() {
        guard let attribute else { return }
        inputView.textFieldView.textField.isEditable = canEdit()

        if attribute.isUserCustom() {
            inputView.title = nil
        } else {
            inputView.title = SPLKDashboardBlueprint.briefTitle(withAttrID: attribute.identifier)
        }

        let doubleValue = (attribute.value as? NSNumber)?.doubleValue ?? 0

        if attribute.isUserCustom() {
            inputView.viewStyle = .horizontal
            inputView.textFieldView.textField.stringValue = NSString.splk_string(from: doubleValue, decimal: 6) ?? ""

        } else {
            if horizontalAttrs.contains(attribute.identifier) {
                inputView.viewStyle = .horizontal
                inputView.textFieldView.textField.stringValue = NSString.splk_string(from: doubleValue, decimal: 3) ?? ""
            } else {
                inputView.viewStyle = .vertical
                inputView.textFieldView.textField.stringValue = NSString.splk_string(from: doubleValue, decimal: 2) ?? ""
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
        if SPLKDashboardTextControlEditingFlag.sharedInstance.shouldIgnoreTextEditingChangeEvent {
            NSLog("忽略 controlTextDidEndEditing 事件，驳回")
            return
        }
        guard let attribute else { return }
        guard var expectedValue = SPLKNumberInputView.parsedValue(with: inputView.textFieldView.textField.stringValue, attrType: attribute.attrType) else {
            NSLog("输入格式校验不通过，驳回")
            renderWithAttribute()
            return
        }

        if attribute.identifier == SPLKAttr_ViewLayer_Visibility_Opacity || attribute.identifier == SPLKAttr_ViewLayer_Shadow_Opacity {
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
