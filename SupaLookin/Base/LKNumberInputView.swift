//
//  LKNumberInputView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/2/22.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

enum LKNumberInputViewStyle {
    /// titleLabel 在输入框内部的右侧
    case horizontal
    /// titleLabel 在输入框的下面
    case vertical
}

let LKNumberInputHorizontalHeight: CGFloat = 21
let LKNumberInputVerticalHeight: CGFloat = 38

final class LKNumberInputView: LKBaseView {

    let textFieldView = LKTextFieldView()
    private let titleLabel = LKLabel()

    var viewStyle: LKNumberInputViewStyle = .horizontal {
        didSet {
            switch viewStyle {
            case .horizontal:
                textFieldView.textField.alignment = .left
                textFieldView.insets = NSEdgeInsets(top: 3, left: 3, bottom: 3, right: 3)
            case .vertical:
                textFieldView.textField.alignment = .center
                textFieldView.insets = NSEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
            }
            updateTitleLabelFontAndColor()
            needsLayout = true
        }
    }

    var title: String? {
        didSet {
            titleLabel.stringValue = title ?? ""
            updateTitleLabelFontAndColor()
            needsLayout = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        textFieldView.backgroundColorName = "DashboardCardValueBGColor"
        textFieldView.layer?.cornerRadius = DashboardCardControlCornerRadius
        let cell = NSTextFieldCell()
        textFieldView.textField.cell = cell
        cell.focusRingType = .none
        cell.usesSingleLineMode = true
        cell.lineBreakMode = .byTruncatingTail
        cell.isScrollable = true
        cell.isEditable = true
        cell.isSelectable = true
        textFieldView.textField.drawsBackground = false
        textFieldView.textField.textColor = NSColor(named: "DashboardCardValueColor")
        textFieldView.textField.font = .systemFont(ofSize: 12)
        addSubview(textFieldView)

        titleLabel.alignment = .center
        addSubview(titleLabel)
    }

    override func layout() {
        super.layout()
        textFieldView.fillWidth().setHeight(LKNumberInputHorizontalHeight)
        switch viewStyle {
        case .horizontal:
            titleLabel.fitSize().limitWidth(min: 15).centerVertically().alignRight(2)
            var insets = textFieldView.insets
            insets.right = frame.width - titleLabel.frame.minX + 2
            textFieldView.insets = insets
        case .vertical:
            titleLabel.fitSize().centerHorizontally().setY(textFieldView.frame.maxY + 3)
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        switch viewStyle {
        case .horizontal:
            size.height = LKNumberInputHorizontalHeight
        case .vertical:
            size.height = LKNumberInputVerticalHeight
        }
        return size
    }

    /// 将当前 string 转换成 attrType 格式的对象并返回，如果返回 nil 则说明转换失败
    static func parsedValue(with string: String, attrType: LookinAttrType) -> NSNumber? {
        switch attrType {
        case .int, .long, .longLong:
            var newValue: Int64 = 0
            if Scanner(string: string).scanInt64(&newValue) {
                return NSNumber(value: newValue)
            }
            return nil
        case .float, .double:
            var newValue: Double = 0
            if Scanner(string: string).scanDouble(&newValue) {
                return NSNumber(value: newValue)
            }
            return nil
        default:
            assertionFailure("不支持该 AttrType")
            return nil
        }
    }

    private func updateTitleLabelFontAndColor() {
        if viewStyle == .horizontal {
            if (title?.count ?? 0) > 1 {
                titleLabel.textColor = NSColor(named: "DashboardCardValueColor")
                titleLabel.font = .systemFont(ofSize: 12)
            } else {
                titleLabel.textColor = NSColor(named: "DashboardInputAccessoryColor")
                titleLabel.font = .systemFont(ofSize: 10)
            }
        } else {
            titleLabel.font = .systemFont(ofSize: 11)
            titleLabel.textColor = NSColor(named: "DashboardCardValueColor")
        }
        needsLayout = true
    }
}
