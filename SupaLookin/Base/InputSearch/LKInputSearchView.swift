//
//  LKInputSearchView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/2.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine

protocol LKInputSearchViewDelegate: AnyObject {
    func inputSearchView(_ view: LKInputSearchView, suggestionsFor string: String) -> [LKInputSearchSuggestionItem]?
    func inputSearchView(_ view: LKInputSearchView, submitText text: String)
}

final class LKInputSearchView: LKBaseView, NSTextFieldDelegate {

    private let textFieldView = LKTextFieldView()
    private let suggestionWc = LKInputSearchSuggestionWindowController()
    private var previousInput: String?
    private var cancellables = Set<AnyCancellable>()

    var horizontalInset: CGFloat = 0

    weak var delegate: LKInputSearchViewDelegate?

    var textField: NSTextField {
        textFieldView.textField
    }

    init(throttleTime: CGFloat) {
        super.init(frame: .zero)

        textFieldView.textField.delegate = self
        textFieldView.insets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textFieldView.textField.isEditable = true
        textFieldView.textField.isBordered = false
        textFieldView.textField.isBezeled = false
        textFieldView.textField.usesSingleLineMode = true
        textFieldView.textField.backgroundColor = .clear
        textFieldView.textField.lineBreakMode = .byTruncatingTail
        textFieldView.textField.font = .systemFont(ofSize: 13)
        addSubview(textFieldView)

        suggestionWc.suggestionsView.tableView.onAction { [weak self] _ in
            self?.handleClickTableView()
        }

        let textField = textFieldView.textField
        // ReactiveObjC's throttle only forwards the latest text once typing pauses, and rac_textSignal starts with the current text.
        NotificationCenter.default.publisher(for: NSControl.textDidChangeNotification, object: textField)
            .map { _ in textField.stringValue }
            .prepend(textField.stringValue)
            .debounce(for: .seconds(Double(throttleTime)), scheduler: RunLoop.main)
            .sink { [weak self] text in
                self?.handleThrottledText(text)
            }
            .store(in: &cancellables)
    }

    override convenience init(frame frameRect: NSRect) {
        self.init(throttleTime: 0)
    }

    private func handleThrottledText(_ text: String) {
        let items = delegate?.inputSearchView(self, suggestionsFor: text)
        suggestionWc.suggestionsView.items = items
        if let items, !items.isEmpty, textField.stringValue == text, let suggestionWindow = suggestionWc.window {
            window?.addChildWindow(suggestionWindow, ordered: .above)
            needsLayout = true
        } else {
            suggestionWc.close()
        }
    }

    override func layout() {
        super.layout()
        textFieldView.setX(horizontalInset).extendToRight(horizontalInset).fillHeight()

        if let superview, let window, let contentView = window.contentView {
            let selfOrigin = contentView.convert(frame.origin, from: superview)
            let mainWindowFrame = window.frame
            let panelSize = suggestionWc.suggestionsView.bestSize()
            let panelHeight = panelSize.height
            let panelWidth = min(panelSize.width, 500)

            var y = mainWindowFrame.origin.y + contentView.frame.size.height - selfOrigin.y - panelHeight - frame.size.height
            if y < 200 {
                // 底部空间不够，放到上面
                y += panelHeight + frame.size.height
            }
            suggestionWc.window?.setFrame(CGRect(x: mainWindowFrame.origin.x + selfOrigin.x, y: y, width: panelWidth, height: panelHeight), display: true)
        }
    }

    private func handleClickTableView() {
        if let text = suggestionWc.suggestionsView.currentSelectedItem()?.text {
            textField.stringValue = text
            suggestionWc.close()
        }
    }

    func clearContentAndSuggestions() {
        if !textField.stringValue.isEmpty {
            previousInput = textField.stringValue
        }
        textField.stringValue = ""
        suggestionWc.close()
    }

    // MARK: - NSTextFieldDelegate

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        let suggestionWindowVisible = suggestionWc.window?.isVisible ?? false

        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            if !suggestionWindowVisible || suggestionWc.suggestionsView.currentSelectedItem() == nil {
                if let previousInput {
                    textField.stringValue = previousInput
                    return true
                }
            }
        }

        if commandSelector == #selector(NSResponder.moveDown(_:)) || commandSelector == #selector(NSResponder.moveUp(_:)) {
            if suggestionWindowVisible, let event = NSApp.currentEvent {
                suggestionWc.suggestionsView.tableView.keyDown(with: event)
                return true
            }
        }

        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if suggestionWindowVisible, let text = suggestionWc.suggestionsView.currentSelectedItem()?.text {
                textField.stringValue = text
                suggestionWc.close()
                return true
            }

            let input = textField.stringValue.trimmingCharacters(in: .whitespaces)
            if !input.isEmpty {
                delegate?.inputSearchView(self, submitText: input)
                return true
            }

            // 防止 textField 失去焦点
            return true
        }
        return false
    }

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        suggestionWc.close()
        return true
    }
}
