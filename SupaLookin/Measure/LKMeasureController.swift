//
//  LKMeasureController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/10/18.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import LookinShared

final class LKMeasureController: LKBaseViewController {

    private let tutorialView = LKMeasureTutorialView()
    private let resultView = LKMeasureResultView()
    private let dataSource: LKHierarchyDataSource
    private var shortcutLabel: LKLabel?
    private var lockSwitchButton: NSButton?

    init(dataSource: LKHierarchyDataSource) {
        self.dataSource = dataSource
        super.init(containerView: nil)

        view.addSubview(tutorialView)
        view.addSubview(resultView)

        dataSource.preferenceManager.measureState.subscribe(self) { target, params in
            target.measureStatePropertyDidChange(params)
        }

        dataSource.selectedItemPublisher
            .combineLatest(dataSource.hoveredItemPublisher)
            .sink { [weak self] _ in
                self?.reRender()
            }
            .store(in: &cancellables)
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        let titleHeight = LKNavigationManager.sharedInstance.windowTitleBarHeight

        var contentView: NSView?
        if tutorialView.isVisible {
            tutorialView.fillWidth().fitHeight().centerVertically().offset(y: titleHeight / 2.0)
            contentView = tutorialView
        }
        if resultView.isVisible {
            resultView.fillWidth().fitHeight().centerVertically().offset(y: titleHeight / 2.0)
            contentView = resultView
        }
        let contentMaxY = contentView?.frame.maxY ?? 0
        if let shortcutLabel {
            shortcutLabel.fitSize().centerHorizontally().setY(contentMaxY + 5)
        }
        if let lockSwitchButton {
            lockSwitchButton.fitSize().centerHorizontally().setY(contentMaxY + 5)
        }
    }

    private func measureStatePropertyDidChange(_ params: LookinMsgActionParams) {
        shortcutLabel?.isHidden = true

        let state = LookinMeasureState(rawValue: params.integerValue)
        switch state {
        case .no:
            lockSwitchButton?.isHidden = true
            lockSwitchButton?.state = .off

        case .unlocked:
            // 由快捷键触发
            let button: NSButton
            if let lockSwitchButton {
                button = lockSwitchButton
            } else {
                button = NSButton()
                button.setButtonType(.switch)
                button.font = .systemFont(ofSize: 15)
                button.title = NSLocalizedString("Cancel measure after key up.", comment: "")
                button.onAction { [unowned self] _ in
                    self.handleLockSwitchButton()
                }
                view.addSubview(button)
                lockSwitchButton = button
            }
            button.state = .on
            button.isHidden = false

        case .locked:
            let label: LKLabel
            if let shortcutLabel {
                label = shortcutLabel
            } else {
                label = LKLabel()
                label.stringValue = NSLocalizedString("shortcut: holding \"option\" key", comment: "")
                label.textColor = .secondaryLabelColor
                view.addSubview(label)
                shortcutLabel = label
            }
            label.isHidden = false

        case nil:
            break
        }
        reRender()
    }

    private func reRender() {
        if dataSource.preferenceManager.measureState.currentIntegerValue == LookinMeasureState.no.rawValue {
            return
        }
        guard let selectedItem = dataSource.selectedItem else {
            return
        }
        guard let hoveredItem = dataSource.hoveredItem, selectedItem !== hoveredItem else {
            let format = NSLocalizedString("to measure between it and selected %@.", comment: "")
            let subtitle = String(format: format, selectedItem.title ?? "(null)")

            resultView.isHidden = true
            tutorialView.isHidden = false
            tutorialView.render(withImage: NSImage(named: "measure_hover"), title: NSLocalizedString("Hover on a layer", comment: ""), subtitle: subtitle)
            view.needsLayout = true
            return
        }

        var sizeInvalidClass: String?
        var sizeInvalidProperty: String?
        let selectedItemFrame = selectedItem.calculateFrameToRoot()
        let hoveredItemFrame = hoveredItem.calculateFrameToRoot()

        if selectedItemFrame.size.width <= 0 {
            sizeInvalidClass = selectedItem.title
            sizeInvalidProperty = "width"
        } else if selectedItemFrame.size.height <= 0 {
            sizeInvalidClass = selectedItem.title
            sizeInvalidProperty = "height"
        } else if hoveredItemFrame.size.width <= 0 {
            sizeInvalidClass = hoveredItem.title
            sizeInvalidProperty = "width"
        } else if hoveredItemFrame.size.height <= 0 {
            sizeInvalidClass = hoveredItem.title
            sizeInvalidProperty = "height"
        }
        if sizeInvalidClass != nil || sizeInvalidProperty != nil {
            let subtitleFormat = NSLocalizedString("Selected %@'s %@ is less than or equal to 0.", comment: "")
            let subtitle = String(format: subtitleFormat, sizeInvalidClass ?? "(null)", sizeInvalidProperty ?? "(null)")

            resultView.isHidden = true
            tutorialView.isHidden = false
            tutorialView.render(withImage: NSImage(named: "measure_info"), title: NSLocalizedString("Invalid Size", comment: ""), subtitle: subtitle)
            view.needsLayout = true
            return
        }

        tutorialView.isHidden = true
        resultView.isHidden = false
        resultView.render(withMainRect: selectedItemFrame, mainImage: selectedItem.groupScreenshot, referRect: hoveredItemFrame, referImage: hoveredItem.groupScreenshot)
        view.needsLayout = true
    }

    private func handleLockSwitchButton() {
        guard let lockSwitchButton else {
            return
        }
        if lockSwitchButton.state == .on {
            dataSource.preferenceManager.measureState.setIntegerValue(LookinMeasureState.unlocked.rawValue, ignoreSubscriber: self)
        } else {
            dataSource.preferenceManager.measureState.setIntegerValue(LookinMeasureState.locked.rawValue, ignoreSubscriber: self)
        }
    }
}
