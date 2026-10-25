//
//  LKPreferencePopupView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/2/28.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKPreferencePopupView: LKBaseView {

    private let titleLabel = LKLabel()
    private let button = NSPopUpButton()
    private let messageLabel = LKLabel()
    private let messages: [String]

    var selectedIndex = 0 {
        didSet {
            messageLabel.stringValue = messages.element(at: selectedIndex) ?? ""
            button.selectItem(at: selectedIndex)
            didChange?(selectedIndex)
        }
    }

    var didChange: ((Int) -> Void)?

    var isEnabled = true {
        didSet {
            button.isEnabled = isEnabled
        }
    }

    var buttonX: CGFloat = 0 {
        didSet {
            needsLayout = true
        }
    }

    convenience init(title: String, message: String?, options: [String]) {
        // lookin_arrayWithCount drops nil, so a nil message leaves no messages at all
        let messages = message.map { message in options.map { _ in message } } ?? []
        self.init(title: title, messages: messages, options: options)
    }

    init(title: String, messages: [String], options: [String]) {
        self.messages = messages
        super.init(frame: .zero)

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: LKHelper.isEnglish ? 13 : 15)
        addSubview(titleLabel)

        button.font = .systemFont(ofSize: LKHelper.isEnglish ? 13 : 14)
        button.onAction { [unowned self] button in
            self.selectedIndex = button.indexOfSelectedItem
            self.didChange?(self.selectedIndex)
        }
        button.addItems(withTitles: options)
        button.isEnabled = isEnabled
        addSubview(button)

        messageLabel.font = .systemFont(ofSize: LKHelper.isEnglish ? 12 : 13)
        messageLabel.textColor = .secondaryLabelColor
        addSubview(messageLabel)
    }

    override func layout() {
        super.layout()
        let buttonHeight = button.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)).height
        button.setWidth(200).setHeight(buttonHeight + 2).setX(buttonX).setY(0)
        messageLabel.setX(button.frame.minX).extendToRight(0).setY(button.frame.maxY + 4).extendToBottom(0)
        titleLabel.fitSize().setMaxX(buttonX - 3).setY(0)
    }
}
