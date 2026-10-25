//
//  LKHierarchyHandlersPopoverItemView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/8/11.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKHierarchyHandlersPopoverItemView: LKBaseView {

    private let eventHandler: LookinEventHandler
    private let iconImageView = NSImageView()
    private let titleLabel = LKLabel()
    private var subtitleLabel: LKLabel?
    private var recognizerEnableButton: NSButton?
    private let contentView = LKTextsMenuView()
    private let topSepLayer = CALayer()

    private let contentX: CGFloat = 28
    private let insetRight: CGFloat = 16
    private let verInset: CGFloat = 10
    private let contentMarginTop: CGFloat = 4
    private let subtitleMarginTop: CGFloat = 3

    var needTopBorder = false {
        didSet {
            topSepLayer.isHidden = !needTopBorder
        }
    }

    /// read 模式下的 editable 需要传入 false
    init(eventHandler: LookinEventHandler, editable: Bool) {
        self.eventHandler = eventHandler
        super.init(frame: .zero)

        layer?.addSublayer(topSepLayer)

        addSubview(iconImageView)

        titleLabel.isSelectable = true
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(titleLabel)

        contentView.font = .systemFont(ofSize: 13)
        addSubview(contentView)

        topSepLayer.backgroundColor = isDarkMode ? NSColor(lookinRed: 255, green: 255, blue: 255, alpha: 0.15).cgColor : NSColor(lookinRed: 0, green: 0, blue: 0, alpha: 0.12).cgColor

        var texts: [LookinStringTwoTuple] = []
        if eventHandler.handlerType == .gesture {
            texts.append(LookinStringTwoTuple(first: "Enabled", second: ""))
            if editable {
                let button = NSButton()
                button.setButtonType(.switch)
                button.title = ""
                button.onAction { [weak self] button in
                    self?.handleGestureButton(button)
                }
                recognizerEnableButton = button
                renderRecognizerEnabledButton()
                contentView.addButton(button, at: 0)
            } else {
                texts.append(LookinStringTwoTuple(first: "Enabled", second: eventHandler.gestureRecognizerIsEnabled ? "YES" : "NO"))
            }

            texts.append(LookinStringTwoTuple(first: "Delegate", second: eventHandler.gestureRecognizerDelegator ?? "nil"))
            // gesture 的名字都太长了，把字号弄小一点
            titleLabel.font = .boldSystemFont(ofSize: 12)
        } else {
            titleLabel.font = .boldSystemFont(ofSize: 13)
        }

        let targetActions = eventHandler.targetActions ?? []
        if targetActions.isEmpty {
            texts.append(LookinStringTwoTuple(first: "Target", second: "nil"))
            texts.append(LookinStringTwoTuple(first: "Action", second: "NULL"))
        } else if targetActions.count == 1 {
            let tuple = targetActions[0]
            texts.append(LookinStringTwoTuple(first: "Target", second: tuple.first))
            texts.append(LookinStringTwoTuple(first: "Action", second: tuple.second))
        } else {
            for (idx, tuple) in targetActions.enumerated() {
                texts.append(LookinStringTwoTuple(first: "Target \(idx + 1)", second: tuple.first))
                texts.append(LookinStringTwoTuple(first: "Action \(idx + 1)", second: tuple.second))
            }
        }
        contentView.texts = texts
        titleLabel.stringValue = eventHandler.eventName ?? ""
        if eventHandler.handlerType == .gesture {
            iconImageView.image = NSImage(named: "icon_gesture_tap")
        } else if eventHandler.eventName?.hasPrefix("UIControlEventEditing") == true {
            iconImageView.image = NSImage(named: "icon_targetaction_edit")
        } else {
            iconImageView.image = NSImage(named: "icon_targetaction_touch")
        }

        if eventHandler.handlerType == .gesture {
            var subtitleTexts: [String] = []
            if let inheritedRecognizerName = eventHandler.inheritedRecognizerName {
                subtitleTexts.append("\(NSLocalizedString("Inherits from", comment: "")) \(inheritedRecognizerName)")
            }
            subtitleTexts.append(contentsOf: eventHandler.recognizerIvarTraces ?? [])
            if !subtitleTexts.isEmpty {
                let label = LKLabel()
                label.textColor = isDarkMode ? NSColor.lookinGray9.withAlphaComponent(0.5) : NSColor.lookinGray1.withAlphaComponent(0.6)
                label.stringValue = subtitleTexts.joined(separator: "\n")
                label.isSelectable = true
                label.font = .systemFont(ofSize: 12)
                label.maximumNumberOfLines = 0
                label.lineBreakMode = .byTruncatingMiddle
                addSubview(label)
                subtitleLabel = label
            }
        }
    }

    override func layout() {
        super.layout()
        topSepLayer.setX(contentX).extendToRight(insetRight).setY(0).setHeight(1)

        titleLabel.setX(contentX).extendToRight(insetRight).fitHeight().setY(verInset)

        var y = titleLabel.frame.maxY
        if let subtitleLabel {
            subtitleLabel.setX(contentX).extendToRight(insetRight).fitHeight().setY(y + subtitleMarginTop)
            y = subtitleLabel.frame.maxY
        }

        contentView.setX(contentX).extendToRight(insetRight).fitHeight().setY(y + contentMarginTop)
        iconImageView.fitSize().setMidX(contentX / 2.0 + 1).setMidY(titleLabel.frame.midY)
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        let titleSize = titleLabel.bestSize
        let contentSize = contentView.sizeThatFits(.max)
        let subtitleSize = subtitleLabel?.bestSize ?? .zero
        var size = limitedSize
        // 加个 2 冗余一下像素取整误差
        size.width = max(max(titleSize.width, contentSize.width), subtitleSize.width) + contentX + insetRight + 2
        size.height = titleSize.height + contentSize.height + contentMarginTop + verInset * 2
        if subtitleLabel != nil {
            size.height += subtitleMarginTop + subtitleSize.height
        }
        return size
    }

    private func handleGestureButton(_ button: NSButton) {
        let mainWindow = LKNavigationManager.sharedInstance.staticWindowController?.window

        guard let app = LKAppsManager.sharedInstance.inspectingApp else {
            LKHelper.alertError(LookinError.noConnect, window: mainWindow)
            renderRecognizerEnabledButton()
            return
        }
        let shouldEnableRecognizer = button.state == .on
        let recognizerOid = UInt(eventHandler.recognizerOid)
        Task { [weak self] in
            do {
                let enabled = try await app.modifyGestureRecognizer(recognizerOid, toBeEnabled: shouldEnableRecognizer)
                guard let self else { return }
                self.eventHandler.gestureRecognizerIsEnabled = (enabled as? NSNumber)?.boolValue ?? false
                self.renderRecognizerEnabledButton()
            } catch {
                LKHelper.alertError(error, window: mainWindow)
                self?.renderRecognizerEnabledButton()
            }
        }
    }

    private func renderRecognizerEnabledButton() {
        recognizerEnableButton?.state = eventHandler.gestureRecognizerIsEnabled ? .on : .off
    }
}
