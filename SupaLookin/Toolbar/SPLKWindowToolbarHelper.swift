//
//  SPLKWindowToolbarHelper.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/8.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import SPLKServer

let SPLKToolBarIdentifier_Dimension = NSToolbarItem.Identifier("0")
let SPLKToolBarIdentifier_Scale = NSToolbarItem.Identifier("1")
let SPLKToolBarIdentifier_Setting = NSToolbarItem.Identifier("2")
let SPLKToolBarIdentifier_Reload = NSToolbarItem.Identifier("3")
let SPLKToolBarIdentifier_App = NSToolbarItem.Identifier("5")
let SPLKToolBarIdentifier_AppInReadMode = NSToolbarItem.Identifier("12")
let SPLKToolBarIdentifier_Add = NSToolbarItem.Identifier("13")
let SPLKToolBarIdentifier_Remove = NSToolbarItem.Identifier("14")
let SPLKToolBarIdentifier_Console = NSToolbarItem.Identifier("15")
let SPLKToolBarIdentifier_Rotation = NSToolbarItem.Identifier("16")
let SPLKToolBarIdentifier_Measure = NSToolbarItem.Identifier("17")
let SPLKToolBarIdentifier_Message = NSToolbarItem.Identifier("18")
let SPLKToolBarIdentifier_FastMode = NSToolbarItem.Identifier("19")

private let Key_AppObservation = "AppObservation"

final class SPLKWindowToolbarHelper {

    static let sharedInstance = SPLKWindowToolbarHelper()

    private init() {}

    /**
     通过以下 identifier 创建的 toolBarItem 需要业务自己设置点击 action:
     - Reload
     - App
     - Add
     - Remove
     - Setting
     */
    func makeToolBarItem(withIdentifier identifier: NSToolbarItem.Identifier, preferenceManager manager: SPLKPreferenceManager) -> NSToolbarItem? {
        assert(identifier != SPLKToolBarIdentifier_AppInReadMode, "请使用 makeAppInReadModeItem(withAppInfo:) 方法")

        if identifier == SPLKToolBarIdentifier_Measure {
            let image = NSImage(named: "icon_measure")
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded
            button.setButtonType(.pushOnPushOff)
            button.onAction { [weak manager, unowned self] button in
                // The button targets the helper, so the helper's own subscription doesn't echo the change back.
                let state: SPLKMeasureState = button.state == .on ? .locked : .no
                manager?.measureState.setIntegerValue(state.rawValue, ignoreSubscriber: self)
            }

            let item = NSToolbarItem(itemIdentifier: SPLKToolBarIdentifier_Measure)
            item.label = NSLocalizedString("Measure", comment: "")
            item.view = button
            item.minSize = NSSize(width: 48, height: 34)
            manager.measureState.subscribe(self, relatedObject: button, sendAtOnce: true) { _, param in
                let button = param.relatedObject as? NSButton
                let measureState = param.integerValue
                button?.state = measureState != SPLKMeasureState.no.rawValue ? .on : .off
            }
            return item
        }

        if identifier == SPLKToolBarIdentifier_Rotation {
            let image = NSImage(named: "icon_rotation")
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded
            button.setButtonType(.pushOnPushOff)

            let item = NSToolbarItem(itemIdentifier: SPLKToolBarIdentifier_Rotation)
            item.label = NSLocalizedString("Free Rotation", comment: "")
            item.view = button
            item.minSize = NSSize(width: 48, height: 34)
            manager.freeRotation.subscribe(self, relatedObject: button, sendAtOnce: true) { _, param in
                (param.relatedObject as? NSButton)?.state = param.boolValue ? .on : .off
            }
            return item
        }

        if identifier == SPLKToolBarIdentifier_Dimension {
            let image_2d = NSImage(named: "icon_2d") ?? NSImage()
            image_2d.isTemplate = true
            let image_3d = NSImage(named: "icon_3d") ?? NSImage()
            image_3d.isTemplate = true

            let control = NSSegmentedControl(images: [image_2d, image_3d], trackingMode: .selectOne, target: nil, action: nil)
            control.onAction { [weak manager, unowned self] control in
                manager?.previewDimension.setIntegerValue(control.selectedSegment, ignoreSubscriber: self)
            }
            control.segmentDistribution = .fillEqually

            let item = NSToolbarItem(itemIdentifier: SPLKToolBarIdentifier_Dimension)
            item.label = "2D / 3D"
            item.view = control
            item.minSize = NSSize(width: 90, height: 34)
            manager.previewDimension.subscribe(self, relatedObject: control, sendAtOnce: true) { _, param in
                (param.relatedObject as? NSSegmentedControl)?.selectedSegment = param.integerValue
            }
            return item
        }

        if identifier == SPLKToolBarIdentifier_Scale {
            let scale = manager.previewScale.currentDoubleValue

            let item = NSToolbarItem(itemIdentifier: SPLKToolBarIdentifier_Scale)
            let scaleView = SPLKWindowToolbarScaleView()
            scaleView.slider.minValue = Double(SPLKPreviewMinScale)
            scaleView.slider.maxValue = Double(SPLKPreviewMaxScale)
            scaleView.slider.doubleValue = scale
            scaleView.slider.onAction { [weak manager, unowned self] slider in
                manager?.previewScale.setDoubleValue(slider.doubleValue, ignoreSubscriber: self)
            }
            scaleView.increaseButton.onAction { [weak manager] _ in
                guard let manager else { return }
                let targetScale = min(max(manager.previewScale.currentDoubleValue + 0.1, Double(SPLKPreviewMinScale)), Double(SPLKPreviewMaxScale))
                manager.previewScale.setDoubleValue(targetScale, ignoreSubscriber: nil)
            }
            scaleView.decreaseButton.onAction { [weak manager] _ in
                guard let manager else { return }
                let targetScale = min(max(manager.previewScale.currentDoubleValue - 0.1, Double(SPLKPreviewMinScale)), Double(SPLKPreviewMaxScale))
                manager.previewScale.setDoubleValue(targetScale, ignoreSubscriber: nil)
            }

            item.label = NSLocalizedString("Zoom", comment: "")
            item.view = scaleView
            item.minSize = NSSize(width: 160, height: 34)

            manager.previewScale.subscribe(self, relatedObject: scaleView.slider, sendAtOnce: true) { _, param in
                (param.relatedObject as? NSSlider)?.doubleValue = param.doubleValue
            }
            return item
        }

        if identifier == SPLKToolBarIdentifier_Setting {
            let image = NSImage(named: "icon_setting")
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded

            let item = NSToolbarItem(itemIdentifier: SPLKToolBarIdentifier_Setting)
            item.view = button
            item.minSize = NSSize(width: 48, height: 34)
            return item
        }

        if identifier == SPLKToolBarIdentifier_Reload {
            let image = NSImage(named: "icon_reload")
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded

            let item = NSToolbarItem(itemIdentifier: SPLKToolBarIdentifier_Reload)
            item.label = NSLocalizedString("Reload", comment: "")
            item.view = button
            item.minSize = NSSize(width: 68, height: 34)
            return item
        }

        if identifier == SPLKToolBarIdentifier_App {
            let button = SPLKWindowToolbarAppButton()
            button.bezelStyle = .texturedRounded

            let item = NSToolbarItem(itemIdentifier: SPLKToolBarIdentifier_App)
            item.label = NSLocalizedString("Select App", comment: "")
            item.view = button

            // Bound to the item, so the subscription ends when the item is released, as RAC's takeUntil(rac_willDeallocSignal) did.
            let observation = SPLKAppsManager.sharedInstance.inspectingAppPublisher
                .sink { [weak item, weak button] app in
                    guard let item, let button else { return }
                    button.appInfo = app?.appInfo
                    if app != nil {
                        item.minSize = NSSize(width: button.bestWidth + 6, height: 34)
                    } else {
                        item.minSize = NSSize(width: 42, height: 34)
                    }
                    item.maxSize = item.minSize
                }
            item.splk_bindObject(observation, forKey: Key_AppObservation)
            return item
        }

        if identifier == SPLKToolBarIdentifier_Console {
            let image = NSImage(named: "icon_console")
            image?.isTemplate = true
            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded
            button.setButtonType(.pushOnPushOff)

            let item = NSToolbarItem(itemIdentifier: SPLKToolBarIdentifier_Console)
            item.label = NSLocalizedString("Console", comment: "")
            item.view = button
            item.minSize = NSSize(width: 48, height: 34)
            return item
        }

        if identifier == SPLKToolBarIdentifier_FastMode {
            let image = NSImage(named: "icon_turbo")
            image?.isTemplate = true
            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded
            button.setButtonType(.pushOnPushOff)

            let item = NSToolbarItem(itemIdentifier: SPLKToolBarIdentifier_FastMode)
            item.label = NSLocalizedString("Fast Mode", comment: "")
            item.view = button
            item.minSize = NSSize(width: 60, height: 34)

            manager.fastMode.subscribe(self, relatedObject: button, sendAtOnce: true) { _, param in
                (param.relatedObject as? NSButton)?.state = param.boolValue ? .on : .off
            }
            return item
        }

        if identifier == SPLKToolBarIdentifier_Add {
            let image = NSImage(named: NSImage.addTemplateName)
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded

            let item = NSToolbarItem(itemIdentifier: SPLKToolBarIdentifier_Add)
            item.view = button
            item.minSize = NSSize(width: 48, height: 34)
            return item
        }

        if identifier == SPLKToolBarIdentifier_Remove {
            let image = NSImage(named: "icon_delete")
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded

            let item = NSToolbarItem(itemIdentifier: SPLKToolBarIdentifier_Remove)
            item.view = button
            item.minSize = NSSize(width: 48, height: 34)
            return item
        }

        if identifier == SPLKToolBarIdentifier_Message {
            let image = NSImage(named: "icon_notification")
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded

            let item = NSToolbarItem(itemIdentifier: SPLKToolBarIdentifier_Message)
            item.view = button
            item.minSize = NSSize(width: 48, height: 34)
            return item
        }

        assertionFailure()
        return nil
    }

    /// 请使用该方法初始化 AppInReadMode 这个 item
    func makeAppInReadModeItem(withAppInfo appInfo: SPLKAppInfo?) -> NSToolbarItem {
        let button = SPLKWindowToolbarAppButton()
        button.bezelStyle = .texturedRounded
        button.appInfo = appInfo

        let item = NSToolbarItem(itemIdentifier: SPLKToolBarIdentifier_AppInReadMode)
        item.label = "iOS App"
        item.view = button
        item.minSize = NSSize(width: button.bestWidth + 6, height: 34)

        item.maxSize = item.minSize
        return item
    }
}
