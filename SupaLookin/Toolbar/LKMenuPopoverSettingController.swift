//
//  LKMenuPopoverSettingController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/1/9.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKMenuPopoverSettingController: LKBaseViewController {

    private let manager: LKPreferenceManager

    private let enableOutlineButton = NSButton()
    private let showInvisiblesButton = NSButton()

    private let spaceSlider = NSSlider()
    private let spaceSliderLabel = LKLabel()

    private var preferenceButton: NSButton!

    init(preferenceManager manager: LKPreferenceManager) {
        self.manager = manager
        super.init(containerView: nil)

        enableOutlineButton.setButtonType(.switch)
        enableOutlineButton.font = .systemFont(ofSize: 14)
        enableOutlineButton.title = NSLocalizedString("Show layer outline", comment: "")
        enableOutlineButton.onAction { [unowned self] _ in
            self.handleOutlineControl()
        }
        view.addSubview(enableOutlineButton)
        enableOutlineButton.state = manager.showOutline.currentBOOLValue ? .on : .off

        showInvisiblesButton.font = .systemFont(ofSize: 14)
        showInvisiblesButton.title = NSLocalizedString("Show hidden UIView and CALayer", comment: "")
        showInvisiblesButton.setButtonType(.switch)
        showInvisiblesButton.onAction { [unowned self] _ in
            self.handleShowInvisiblesControl()
        }
        view.addSubview(showInvisiblesButton)
        showInvisiblesButton.state = manager.showHiddenItems.currentBOOLValue ? .on : .off

        spaceSlider.minValue = Double(LookinPreviewMinZInterspace)
        spaceSlider.maxValue = Double(LookinPreviewMaxZInterspace)
        spaceSlider.onAction { [unowned self] slider in
            self.handleSpaceSlider(slider)
        }
        view.addSubview(spaceSlider)

        spaceSliderLabel.font = .systemFont(ofSize: 14)
        spaceSliderLabel.stringValue = NSLocalizedString("Item separation", comment: "")
        view.addSubview(spaceSliderLabel)

        preferenceButton = NSButton.normalButton(title: NSLocalizedString("More…", comment: "")) { _ in
            LKNavigationManager.sharedInstance.showPreference()
        }
        view.addSubview(preferenceButton)

        manager.zInterspace.subscribe(self, sendAtOnce: true) { target, param in
            target.spaceSlider.doubleValue = param.doubleValue
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        enableOutlineButton.setX(15).extendToRight(0).setHeight(24).setY(15)
        showInvisiblesButton.setX(15).extendToRight(0).setHeight(24).setY(enableOutlineButton.frame.maxY + 6)

        spaceSlider.setX(15).extendToRight(15).setHeight(26).setY(showInvisiblesButton.frame.maxY + 22)
        spaceSliderLabel.fitSize().setX(spaceSlider.frame.minX + 3).setY(spaceSlider.frame.maxY)

        preferenceButton.setWidth(130).centerHorizontally().alignBottom(4)
    }

    private func handleOutlineControl() {
        manager.showOutline.setBOOLValue(enableOutlineButton.state == .on, ignoreSubscriber: nil)
    }

    private func handleShowInvisiblesControl() {
        manager.showHiddenItems.setBOOLValue(showInvisiblesButton.state == .on, ignoreSubscriber: nil)
    }

    private func handleSpaceSlider(_ slider: NSSlider) {
        manager.zInterspace.setDoubleValue(slider.doubleValue, ignoreSubscriber: self)
    }
}
