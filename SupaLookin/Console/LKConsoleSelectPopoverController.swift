//
//  LKConsoleSelectPopoverController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/19.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import LookinShared

final class LKConsoleSelectPopoverController: LKBaseViewController {

    private let dataSource: LKConsoleDataSource

    private var historyTitleView: LKImageTextView!
    private var historyControls: [LKConsoleSelectPopoverItemControl] = []
    private var highlightControls: [LKConsoleSelectPopoverItemControl] = []
    private var highlightTitleView: LKImageTextView!
    private var toggleButton: NSButton!
    private var sepLayer: CALayer!

    private let insets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
    private let titleMarginTop: CGFloat = 16
    private let itemControlMarginTop: CGFloat = 5
    private let toggleButtonMarginTop: CGFloat = 22

    var needShowError: ((Error) -> Void)?
    var needClose: (() -> Void)?

    init(dataSource: LKConsoleDataSource) {
        self.dataSource = dataSource
        super.init(containerView: nil)
    }

    override func makeContainerView() -> NSView {
        let view = LKBaseView()

        historyTitleView = LKImageTextView()
        historyTitleView.imageMargins = HorizontalMargins(left: 0, right: 5)
        historyTitleView.imageView.image = NSImage(named: "console_history")
        historyTitleView.label.stringValue = NSLocalizedString("Objects returned recently in console", comment: "")
        view.addSubview(historyTitleView)

        highlightTitleView = LKImageTextView()
        highlightTitleView.imageMargins = HorizontalMargins(left: 0, right: 5)
        highlightTitleView.imageView.image = NSImage(named: "icon_cursor")
        highlightTitleView.label.stringValue = NSLocalizedString("Objects highlighted in hierarchy panel", comment: "")
        view.addSubview(highlightTitleView)

        historyControls = []
        highlightControls = []

        toggleButton = NSButton()
        toggleButton.setButtonType(.switch)
        toggleButton.title = NSLocalizedString("Automatically make highlighted view in hierarchy panel as console target", comment: "")
        toggleButton.font = .systemFont(ofSize: 12)
        toggleButton.onAction { [unowned self] _ in
            self.handleToggleSyncButton()
        }
        view.addSubview(toggleButton)

        LKPreferenceManager.mainManager.syncConsoleTargetPublisher
            .sink { [weak self] shouldChecked in
                self?.toggleButton.state = shouldChecked ? .on : .off
            }
            .store(in: &cancellables)

        sepLayer = CALayer()
        sepLayer.lookin_removeImplicitAnimations()
        view.layer?.addSublayer(sepLayer)
        view.didChangeAppearanceBlock = { [weak self] _, isDarkMode in
            if isDarkMode {
                self?.sepLayer?.backgroundColor = NSColor(white: 1, alpha: 0.2).cgColor
            } else {
                self?.sepLayer?.backgroundColor = NSColor(white: 0, alpha: 0.12).cgColor
            }
        }

        return view
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        var y = insets.top

        if historyTitleView.isVisible {
            historyTitleView.fitSize().setX(insets.left).setY(y)
            y = historyTitleView.frame.maxY
        }
        for control in historyControls {
            control.setX(insets.left).extendToRight(insets.right).fitHeight().setY(y + itemControlMarginTop)
            y = control.frame.maxY
        }
        if highlightTitleView.isVisible {
            if historyTitleView.isVisible {
                y += titleMarginTop
            }
            highlightTitleView.fitSize().setX(insets.left).setY(y)
            y = highlightTitleView.frame.maxY
        }
        for control in highlightControls {
            control.setX(insets.left).extendToRight(insets.right).fitHeight().setY(y + itemControlMarginTop)
            y = control.frame.maxY
        }

        toggleButton.setX(insets.left).extendToRight(insets.right).setY(y + toggleButtonMarginTop).setHeight(toggleButton.sizeThatFits(.max).height + 2)
        sepLayer.setX(insets.left).extendToRight(insets.right).setHeight(1).setY(toggleButton.frame.minY - 7)
    }

    func bestHeight() -> CGFloat {
        var height = insets.top + insets.bottom
        if historyTitleView.isVisible {
            height += historyTitleView.sizeThatFits(.max).height
        }
        if highlightTitleView.isVisible {
            height += highlightTitleView.sizeThatFits(.max).height

            if historyTitleView.isVisible {
                height += titleMarginTop
            }
        }
        for control in historyControls + highlightControls {
            height += control.sizeThatFits(.max).height + itemControlMarginTop
        }

        height += toggleButton.sizeThatFits(.max).height + toggleButtonMarginTop
        return height
    }

    private func makeItemControl() -> LKConsoleSelectPopoverItemControl {
        let control = LKConsoleSelectPopoverItemControl()
        control.clickAction = { [unowned self] control in
            self.handleControl(control as! LKConsoleSelectPopoverItemControl)
        }
        view.addSubview(control)
        return control
    }

    func reRender() {
        if dataSource.recentObjects.isEmpty {
            historyControls = historyControls.resized(count: 1, add: { _ in
                self.makeItemControl()
            }, remove: { _, control in
                control.removeFromSuperview()
            }, doNext: { _, control in
                control.title = NSLocalizedString("No object was returned yet", comment: "")
                control.isChecked = false
                control.representedObject = nil
            })
        } else {
            historyControls = historyControls.resized(count: dataSource.recentObjects.count, add: { _ in
                self.makeItemControl()
            }, remove: { _, control in
                control.removeFromSuperview()
            }, doNext: { idx, control in
                let tuple = self.dataSource.recentObjects[idx]
                let targetObject = tuple.object
                control.title = "<\(targetObject.simpleDemangledClassName): \(targetObject.memoryAddress ?? "(null)")>"
                control.subtitle = tuple.message
                control.isChecked = self.dataSource.currentObject?.oid == targetObject.oid
                control.representedObject = targetObject
            })
        }

        let selectedObjects = dataSource.selectedObjects ?? []
        highlightTitleView.isHidden = selectedObjects.isEmpty
        highlightControls = highlightControls.resized(count: selectedObjects.count, add: { _ in
            self.makeItemControl()
        }, remove: { _, control in
            control.removeFromSuperview()
        }, doNext: { idx, control in
            let targetObject = selectedObjects[idx]
            control.title = "<\(targetObject.simpleDemangledClassName): \(targetObject.memoryAddress ?? "(null)")>"
            control.isChecked = self.dataSource.currentObject?.oid == targetObject.oid
            control.representedObject = targetObject
        })

        view.needsLayout = true
    }

    private func handleControl(_ control: LKConsoleSelectPopoverItemControl) {
        guard let obj = control.representedObject else {
            return
        }
        Task { [weak self] in
            do {
                try await self?.dataSource.makeObjectAsCurrent(obj)
                guard let self else { return }
                if obj.oid != self.dataSource.selectedObjects?.last?.oid {
                    LKPreferenceManager.mainManager.syncConsoleTarget = false
                }
                self.needClose?()
            } catch {
                self?.needShowError?(LookinError.noConnect)
            }
        }
    }

    private func handleToggleSyncButton() {
        let mng = LKPreferenceManager.mainManager
        mng.syncConsoleTarget = !mng.syncConsoleTarget
        if mng.syncConsoleTarget {
            Task { [weak self] in
                guard let self else { return }
                if (try? await self.dataSource.makeObjectAsCurrent(self.dataSource.selectedObjects?.last)) != nil {
                    self.reRender()
                }
            }
        }
    }
}
