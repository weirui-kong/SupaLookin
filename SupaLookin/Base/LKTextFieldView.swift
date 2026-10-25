//
//  LKTextFieldView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/2/27.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine

class LKTextFieldView: LKBaseView {

    let textField = NSTextField()

    private var imageView: NSImageView?
    private(set) var closeButton: NSButton?
    private var closeButtonCancellables = Set<AnyCancellable>()

    var insets = NSEdgeInsets() {
        didSet {
            needsLayout = true
        }
    }

    var textColors: LKTwoColors? {
        didSet {
            updateColors()
        }
    }

    var image: NSImage? {
        didSet {
            if let image {
                if imageView == nil {
                    let view = NSImageView()
                    addSubview(view)
                    imageView = view
                }
                imageView?.image = image
            } else {
                imageView?.removeFromSuperview()
                imageView = nil
            }
            needsLayout = true
        }
    }

    static func labelView() -> LKTextFieldView {
        let view = LKTextFieldView()
        view.textField.wantsLayer = true
        view.textField.backgroundColor = .clear
        view.textField.isBezeled = false
        view.textField.drawsBackground = true
        view.textField.isEditable = false
        view.textField.isSelectable = false
        return view
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textField)
    }

    override func layout() {
        super.layout()
        if let imageView {
            if textField.isEditable {
                // 比如 hierarchy 底部的搜索框
                imageView.fitSize().setX(insets.left).centerVertically().offset(y: 1)
                if let closeButton {
                    closeButton.setY(1).extendToBottom(0).setWidth(100).alignRight(insets.right)
                    textField.setX(imageView.frame.maxX + 5).extendToMaxX(closeButton.frame.minX - 5).fitHeight().centerVertically()
                } else {
                    textField.setX(imageView.frame.maxX + 5).extendToRight(insets.right).fitHeight().centerVertically()
                }
            } else {
                // 纯 label，比如 autoLayout popover 的标题
                [imageView, textField].forEach { $0.fitSize().centerVertically() }
                textField.setX(imageView.frame.maxX)
                [imageView, textField].centerGroupHorizontally()
            }
        } else {
            textField.setX(insets.left).extendToRight(insets.right).fitHeight().centerVertically().offset(y: insets.top - insets.bottom)
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var textFieldMaxWidth = limitedSize.width - insets.left - insets.right
        if imageView != nil {
            textFieldMaxWidth -= image?.size.width ?? 0
        }
        let textFieldSize = textField.sizeThatFits(NSSize(width: textFieldMaxWidth, height: .greatestFiniteMagnitude))

        let resultHeight = textFieldSize.height + insets.top + insets.bottom
        var resultWidth = textFieldSize.width + insets.left + insets.right
        if imageView != nil {
            resultWidth += image?.size.width ?? 0
        }
        return NSSize(width: resultWidth, height: resultHeight)
    }

    override func updateColors() {
        super.updateColors()
        if let textColors {
            textField.textColor = textColors.color
        }
    }

    /// 调用该方法后，当输入框内有文字时右侧会有 closeButton
    func initCloseButton() {
        if closeButton != nil {
            return
        }
        let button = NSButton()
        button.title = NSLocalizedString("CancelSearch", comment: "")
        button.bezelStyle = .regularSquare
        addSubview(button)
        closeButton = button
        needsLayout = true

        // 用户手动输入文字只会发出 textDidChange 通知，代码手动设置文字（比如业务逻辑里按下 esc 来清除文字）只会触发 stringValue 的 KVO，这二者配合恰好
        let typed = NotificationCenter.default.publisher(for: NSControl.textDidChangeNotification, object: textField).map { _ in () }
        let assigned = textField.publisher(for: \.stringValue).map { _ in () }
        typed.merge(with: assigned)
            .sink { [weak self] in
                guard let self else { return }
                self.closeButton?.isHidden = self.textField.stringValue.isEmpty
            }
            .store(in: &closeButtonCancellables)
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // 如果不加这个逻辑的话，非编辑状态下点击到了右侧 closeButton 的位置就会无法激活输入框令用户困惑
        if textField.isEditable {
            textField.becomeFirstResponder()
        }
    }
}
