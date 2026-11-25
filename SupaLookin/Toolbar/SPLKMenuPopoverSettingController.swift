//
//  SPLKMenuPopoverSettingController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/1/9.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class SPLKMenuPopoverSettingController: SPLKBaseViewController {

    private let manager: SPLKPreferenceManager

    private let enableOutlineButton = NSButton()
    private let showInvisiblesButton = NSButton()
    private let showMasksButton = NSButton()

    // Only the live window shows these, per 20261125-screenshot-qoi.md.
    private let showsScreenshotFormat: Bool
    private let screenshotFormatLabel = SPLKLabel()
    private let screenshotFormatButton = NSPopUpButton()
    private let screenshotFormats: [SPLKScreenshotFormat] = [.qoiLZ4, .png]

    private let spaceSlider = NSSlider()
    private let spaceSliderLabel = SPLKLabel()

    private var preferenceButton: NSButton!

    static let height: CGFloat = 230
    static let screenshotFormatHeight: CGFloat = 36

    init(preferenceManager manager: SPLKPreferenceManager, showsScreenshotFormat: Bool = false) {
        self.manager = manager
        self.showsScreenshotFormat = showsScreenshotFormat
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

        showMasksButton.font = .systemFont(ofSize: 14)
        showMasksButton.title = NSLocalizedString("Show maskView and mask layer", comment: "")
        showMasksButton.setButtonType(.switch)
        showMasksButton.onAction { [unowned self] _ in
            self.handleShowMasksControl()
        }
        view.addSubview(showMasksButton)
        showMasksButton.state = manager.showMaskItems.currentBOOLValue ? .on : .off

        if showsScreenshotFormat {
            screenshotFormatLabel.font = .systemFont(ofSize: 14)
            screenshotFormatLabel.stringValue = NSLocalizedString("Screenshot format", comment: "")
            view.addSubview(screenshotFormatLabel)

            screenshotFormatButton.font = .systemFont(ofSize: 13)
            screenshotFormatButton.addItems(withTitles: screenshotFormats.map(Self.title))
            screenshotFormatButton.selectItem(at: screenshotFormats.firstIndex(of: manager.screenshotFormat) ?? 0)
            screenshotFormatButton.onAction { [unowned self] button in
                self.manager.screenshotFormat = self.screenshotFormats[button.indexOfSelectedItem]
            }
            view.addSubview(screenshotFormatButton)
        }

        spaceSlider.minValue = Double(SPLKPreviewMinZInterspace)
        spaceSlider.maxValue = Double(SPLKPreviewMaxZInterspace)
        spaceSlider.onAction { [unowned self] slider in
            self.handleSpaceSlider(slider)
        }
        view.addSubview(spaceSlider)

        spaceSliderLabel.font = .systemFont(ofSize: 14)
        spaceSliderLabel.stringValue = NSLocalizedString("Item separation", comment: "")
        view.addSubview(spaceSliderLabel)

        preferenceButton = NSButton.normalButton(title: NSLocalizedString("More…", comment: "")) { _ in
            SPLKNavigationManager.sharedInstance.showPreference()
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

        showMasksButton.setX(15).extendToRight(0).setHeight(24).setY(showInvisiblesButton.frame.maxY + 6)

        var sliderTop = showMasksButton.frame.maxY
        if showsScreenshotFormat {
            screenshotFormatButton.sizeToFit()
            screenshotFormatButton.setY(showMasksButton.frame.maxY + 8).setX(view.bounds.width - 15 - screenshotFormatButton.frame.width)
            screenshotFormatLabel.fitSize().setX(17).setY(screenshotFormatButton.frame.midY - screenshotFormatLabel.frame.height / 2)
            sliderTop = screenshotFormatButton.frame.maxY
        }

        spaceSlider.setX(15).extendToRight(15).setHeight(26).setY(sliderTop + 22)
        spaceSliderLabel.fitSize().setX(spaceSlider.frame.minX + 3).setY(spaceSlider.frame.maxY)

        preferenceButton.setWidth(130).centerHorizontally().alignBottom(4)
    }

    private func handleOutlineControl() {
        manager.showOutline.setBOOLValue(enableOutlineButton.state == .on, ignoreSubscriber: nil)
    }

    private func handleShowInvisiblesControl() {
        manager.showHiddenItems.setBOOLValue(showInvisiblesButton.state == .on, ignoreSubscriber: nil)
    }

    private func handleShowMasksControl() {
        manager.showMaskItems.setBOOLValue(showMasksButton.state == .on, ignoreSubscriber: nil)
    }

    private static func title(_ format: SPLKScreenshotFormat) -> String {
        switch format {
        case .qoiLZ4: "QOI + LZ4"
        case .png: "PNG"
        }
    }

    private func handleSpaceSlider(_ slider: NSSlider) {
        manager.zInterspace.setDoubleValue(slider.doubleValue, ignoreSubscriber: self)
    }
}
