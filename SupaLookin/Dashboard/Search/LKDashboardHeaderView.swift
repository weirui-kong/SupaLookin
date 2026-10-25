//
//  LKDashboardHeaderView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/9/5.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine

protocol LKDashboardHeaderViewDelegate: AnyObject {
    func dashboardHeaderView(_ view: LKDashboardHeaderView, didToggleActive isActive: Bool)
    func dashboardHeaderView(_ view: LKDashboardHeaderView, didInputString string: String)
}

final class LKDashboardHeaderView: LKBaseView, NSTextFieldDelegate {

    weak var delegate: LKDashboardHeaderViewDelegate?

    private let inputBorderView = NSView()
    private let iconImageView = NSImageView()
    private let textField = NSTextField()
    private let addButton = NSButton()

    private let iconXWhenActive: CGFloat = 11
    private let iconXWhenInactive: CGFloat = 89

    private var cancellables = Set<AnyCancellable>()

    var isActive = false {
        didSet {
            if oldValue == isActive {
                return
            }
            isActiveDidChange()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        inputBorderView.wantsLayer = true
        inputBorderView.layer?.cornerRadius = DashboardCardCornerRadius
        inputBorderView.layer?.borderWidth = 1
        addSubview(inputBorderView)

        iconImageView.image = NSImage(named: "icon_search")
        addSubview(iconImageView)

        textField.placeholderString = NSLocalizedString("properties or methods", comment: "")
        textField.delegate = self
        textField.focusRingType = .none
        textField.isEditable = true
        textField.isBordered = false
        textField.isBezeled = false
        textField.usesSingleLineMode = true
        textField.backgroundColor = .clear
        textField.lineBreakMode = .byTruncatingTail
        textField.font = .systemFont(ofSize: 13)
        textField.isHidden = true
        addSubview(textField)

        addButton.image = NSImage(named: NSImage.addTemplateName)
        addButton.bezelStyle = .rounded
        addButton.onAction { [unowned self] _ in
            self.handleAddButton()
        }
        addButton.frame = NSRect(x: 0, y: 0, width: 84, height: 40)
        addSubview(addButton)

        // rac_textSignal starts with the current text, and RAC's throttle forwards the latest value once typing pauses.
        let textField = self.textField
        NotificationCenter.default.publisher(for: NSControl.textDidChangeNotification, object: textField)
            .map { _ in textField.stringValue }
            .prepend(textField.stringValue)
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink { [weak self] x in
                guard let self else { return }
                self.delegate?.dashboardHeaderView(self, didInputString: x)
            }
            .store(in: &cancellables)

        updateColors()
    }

    override func layout() {
        super.layout()
        if isActive {
            inputBorderView.fillSuperview()
            iconImageView.fitSize().setX(iconXWhenActive)
        } else {
            addButton.setWidth(50).fillHeight().alignRight(-6).offset(y: 1)
            inputBorderView.setX(0).extendToRight(48).fillHeight()
            iconImageView.fitSize().centerVertically().setX(iconXWhenInactive)
        }
        textField.setX(30).extendToRight(2).fitHeight().centerVertically()
    }

    override func updateColors() {
        super.updateColors()
        if isActive {
            inputBorderView.layer?.borderColor = isDarkMode ? NSColor(lookinRed: 70, green: 71, blue: 72).cgColor : NSColor(lookinRed: 198, green: 199, blue: 200).cgColor
        } else {
            inputBorderView.layer?.borderColor = isDarkMode ? NSColor(lookinRed: 47, green: 48, blue: 49).cgColor : NSColor(lookinRed: 220, green: 221, blue: 222).cgColor
        }
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        isActive = true
    }

    func currentInputString() -> String {
        textField.stringValue
    }

    private func isActiveDidChange() {
        updateColors()

        if isActive {
            addButton.animator().alphaValue = 0
            inputBorderView.animator().setFrameSize(frame.size)
            iconImageView.animator().setFrameOrigin(NSPoint(x: iconXWhenActive, y: iconImageView.frame.minY))

            textField.animator().isHidden = false
            textField.becomeFirstResponder()

        } else {
            addButton.animator().alphaValue = 1
            inputBorderView.animator().setFrameSize(NSSize(width: frame.width - 48, height: frame.height))
            iconImageView.animator().setFrameOrigin(NSPoint(x: iconXWhenInactive, y: iconImageView.frame.minY))

            textField.animator().isHidden = true
            textField.stringValue = ""
        }

        delegate?.dashboardHeaderView(self, didToggleActive: isActive)
    }

    private func handleAddButton() {
        let menu = NSMenu()

        let menuItem = NSMenuItem(title: NSLocalizedString("How to add custom properties…", comment: "")) { _ in
            NSWorkspace.shared.open(URL(string: "https://bytedance.feishu.cn/docx/TRridRXeUoErMTxs94bcnGchnlb")!)
        }
        menuItem.image = NSImage(named: "Icon_Inspiration_small")
        menu.addItem(menuItem)

        if let event = NSApplication.shared.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: addButton)
        }
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidEndEditing(_ obj: Notification) {
        isActive = false
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // 按下了 esc 键
            isActive = false
            return true
        }
        return false
    }
}
