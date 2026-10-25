//
//  LKDashboardAttributeTextView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/9/16.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKDashboardAttributeTextView: LKDashboardAttributeView, NSTextViewDelegate {

    private let scrollView: NSScrollView
    private let textView: NSTextView
    private var initialText = ""

    required init(frame frameRect: NSRect) {
        scrollView = LKHelper.scrollableTextView()
        textView = scrollView.documentView as! NSTextView
        super.init(frame: frameRect)

        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = DashboardCardControlCornerRadius
        textView.font = .systemFont(ofSize: 12)
        textView.backgroundColor = NSColor(named: "DashboardCardValueBGColor") ?? .clear
        textView.textContainerInset = NSSize(width: 2, height: 4)
        textView.delegate = self
        addSubview(scrollView)
    }

    override func layout() {
        super.layout()
        scrollView.fillSuperview()
    }

    override func renderWithAttribute() {
        super.renderWithAttribute()
        initialText = attribute?.value as? String ?? ""
        textView.string = initialText
        textView.isEditable = canEdit()
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        size.width -= textView.textContainerInset.width * 2

        let attributes: [NSAttributedString.Key: Any] = [.font: textView.font ?? NSFont.systemFont(ofSize: 12)]
        let attributedString = NSAttributedString(string: textView.string, attributes: attributes)
        let rect = attributedString.boundingRect(with: size, options: .usesLineFragmentOrigin)
        size.height = min(rect.size.height + textView.textContainerInset.height * 2, 80)
        return size
    }

    // MARK: - NSTextViewDelegate

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            window?.makeFirstResponder(nil)
            return true
        }
        return false
    }

    func textDidEndEditing(_ notification: Notification) {
        let expectedValue = textView.string

        if expectedValue == initialText {
            NSLog("修改没有变化，不做任何提交")
            renderWithAttribute()
            return
        }
        // 提交修改
        submitModification(expectedValue)
    }
}
