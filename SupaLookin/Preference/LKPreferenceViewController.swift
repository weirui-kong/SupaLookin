//
//  LKPreferenceViewController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/1/4.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class LKPreferenceViewController: LKBaseViewController {

    private var view_doubleClick: LKPreferencePopupView!
    private var view_appearance: LKPreferencePopupView!
    private var view_colorFormat: LKPreferencePopupView!
    private var view_contrast: LKPreferencePopupView!
    private var resetButton: NSButton!

    override var view: NSView {
        didSet {
            setUp()
        }
    }

    private func setUp() {
        let controlX: CGFloat = LKHelper.isEnglish ? 94 : 84

        view_colorFormat = LKPreferencePopupView(title: NSLocalizedString("Color Format", comment: ""), messages: [NSLocalizedString("Color will be displayed in format like (255, 12, 34, 0.5). Alpha value is between 0 and 1.", comment: ""), NSLocalizedString("Color will be displayed in format like #7e7e7eff. The components are #RRGGBBAA.", comment: "")], options: ["RGBA", "HEX"])
        view_colorFormat.buttonX = controlX
        view_colorFormat.didChange = { selectedIndex in
            LKPreferenceManager.mainManager.rgbaFormat = selectedIndex == 0
        }
        view.addSubview(view_colorFormat)

        let contrastTips = NSLocalizedString("Adjust this option to use a deeper layer selection color.", comment: "")
        view_contrast = LKPreferencePopupView(title: NSLocalizedString("Image contrast", comment: ""), messages: [contrastTips, contrastTips, contrastTips], options: [NSLocalizedString("Normal", comment: ""), NSLocalizedString("Medium", comment: ""), NSLocalizedString("High", comment: "")])
        view_contrast.buttonX = controlX
        view_contrast.didChange = { selectedIndex in
            LKPreferenceManager.mainManager.imageContrastLevel = selectedIndex
        }
        view.addSubview(view_contrast)

        view_appearance = LKPreferencePopupView(title: NSLocalizedString("Appearance", comment: ""), message: nil, options: [NSLocalizedString("Dark Mode", comment: ""), NSLocalizedString("Light Mode", comment: ""), NSLocalizedString("System Default", comment: "")])
        view_appearance.buttonX = controlX
        view_appearance.didChange = { selectedIndex in
            if let type = LookinPreferredAppeanranceType(rawValue: selectedIndex) {
                LKPreferenceManager.mainManager.appearanceType = type
            }
        }
        view.addSubview(view_appearance)

        view_doubleClick = LKPreferencePopupView(title: NSLocalizedString("Double click", comment: ""), message: nil, options: [NSLocalizedString("Expand or collapse layer", comment: ""), NSLocalizedString("Focus on layer", comment: "")])
        view_doubleClick.buttonX = controlX
        view_doubleClick.didChange = { selectedIndex in
            if let behavior = LookinDoubleClickBehavior(rawValue: selectedIndex) {
                LKPreferenceManager.mainManager.doubleClickBehavior = behavior
            }
        }
        view.addSubview(view_doubleClick)

        resetButton = NSButton.normalButton(title: NSLocalizedString("Reset", comment: "")) { [unowned self] _ in
            self.handleResetButton()
        }
        view.addSubview(resetButton)

        renderFromPreferenceManager()
    }

    private func renderFromPreferenceManager() {
        let manager = LKPreferenceManager.mainManager

        view_colorFormat.selectedIndex = manager.rgbaFormat ? 0 : 1
        view_contrast.selectedIndex = manager.imageContrastLevel
        view_appearance.selectedIndex = manager.appearanceType.rawValue
        view_doubleClick.selectedIndex = manager.doubleClickBehavior.rawValue
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        let insets = NSEdgeInsets(top: 20, left: 30, bottom: 10, right: 30)

        view_appearance.setX(insets.left).extendToRight(insets.right).setY(insets.top).setHeight(50)
        view_colorFormat.setX(insets.left).extendToRight(insets.right).setY(view_appearance.frame.maxY).setHeight(80)
        view_contrast.setX(insets.left).extendToRight(insets.right).setY(view_colorFormat.frame.maxY).setHeight(65)

        view_doubleClick.setX(insets.left).extendToRight(insets.right).setY(view_contrast.frame.maxY).setHeight(50)

        resetButton.setWidth(120).alignBottom(insets.bottom).alignRight(insets.right)
    }

    private func handleResetButton() {
        let manager = LKPreferenceManager.mainManager
        manager.appearanceType = .system
        manager.rgbaFormat = true
        manager.doubleClickBehavior = .collapse
        manager.imageContrastLevel = 0
        renderFromPreferenceManager()

#if DEBUG
        LKMessageManager.sharedInstance.reset()
        LKPreferenceManager.mainManager.reset()
        UserDefaults.standard.removeObject(forKey: "IgnoreFastModeTips")
#endif
    }
}
