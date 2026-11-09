//
//  SPLKReadWindowController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/12.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import SPLKServer

final class SPLKReadWindowController: SPLKWindowController, NSToolbarDelegate {

    private let viewController: SPLKReadViewController
    private var toolbarItemsMap: [NSToolbarItem.Identifier: NSToolbarItem] = [:]
    private let preferenceManager: SPLKPreferenceManager

    private var cancellables = Set<AnyCancellable>()

    init(file: SPLKHierarchyFile?) {
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let window = SPLKWindow(contentRect: NSRect(x: 0, y: 0, width: screenSize.width * 0.7, height: screenSize.height * 0.7), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: true)
        window.tabbingMode = .disallowed
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: 800, height: 500)
        window.center()

        preferenceManager = SPLKPreferenceManager()
        viewController = SPLKReadViewController(file: file, preferenceManager: preferenceManager)
        super.init(window: window)

        window.contentView = viewController.view
        contentViewController = viewController

        viewController.hierarchyDataSource.selectedItemPublisher
            .sink { [weak self] item in
                guard let self else { return }
                let measureButton = self.toolbarItemsMap[SPLKToolBarIdentifier_Measure]?.view as? NSButton
                let canMeasure = item != nil
                measureButton?.isEnabled = canMeasure
            }
            .store(in: &cancellables)

        let toolbar = NSToolbar()
        toolbar.displayMode = .iconAndLabel
        toolbar.sizeMode = .regular
        toolbar.delegate = self
        window.toolbar = toolbar
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - NSToolbarDelegate

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [SPLKToolBarIdentifier_AppInReadMode, .flexibleSpace, SPLKToolBarIdentifier_Dimension, SPLKToolBarIdentifier_Rotation, SPLKToolBarIdentifier_Setting, .flexibleSpace, SPLKToolBarIdentifier_Scale, .flexibleSpace, SPLKToolBarIdentifier_Measure]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if let item = toolbarItemsMap[itemIdentifier] {
            return item
        }
        let item: NSToolbarItem?
        if itemIdentifier == SPLKToolBarIdentifier_AppInReadMode {
            item = SPLKWindowToolbarHelper.sharedInstance.makeAppInReadModeItem(withAppInfo: viewController.hierarchyDataSource.rawHierarchyInfo?.appInfo)
        } else {
            item = SPLKWindowToolbarHelper.sharedInstance.makeToolBarItem(withIdentifier: itemIdentifier, preferenceManager: preferenceManager)
        }
        guard let item else {
            return nil
        }
        toolbarItemsMap[itemIdentifier] = item

        if item.itemIdentifier == SPLKToolBarIdentifier_Setting {
            item.label = NSLocalizedString("View", comment: "")
            item.onAction { [unowned self] sender in
                if let button = sender as? NSButton {
                    self.handleSetting(button)
                }
            }
        } else if item.itemIdentifier == SPLKToolBarIdentifier_Rotation {
            item.onAction { [unowned self] _ in
                let boolValue = self.preferenceManager.freeRotation.currentBOOLValue
                self.preferenceManager.freeRotation.setBOOLValue(!boolValue, ignoreSubscriber: nil)
            }
        }
        return item
    }

    // MARK: - Event Handler

    private func handleSetting(_ button: NSButton) {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = NSSize(width: SPLKHelper.isEnglish ? 270 : 350, height: 200)
        popover.contentViewController = SPLKMenuPopoverSettingController(preferenceManager: preferenceManager)
        popover.show(relativeTo: NSRect(x: 0, y: 0, width: button.bounds.size.width, height: button.bounds.size.height), of: button, preferredEdge: .maxY)
    }

    // MARK: - SPLKAppMenuManagerDelegate

    override var supportedAppMenuActions: Set<SPLKAppMenuAction> {
        [.dimension, .zoomIn, .zoomOut, .decreaseInterspace, .increaseInterspace, .expansion, .filter]
    }

    override func appMenuManagerDidSelectDimension() {
        if preferenceManager.previewDimension.currentIntegerValue == SPLKPreviewDimension.dimension2D.rawValue {
            preferenceManager.previewDimension.setIntegerValue(SPLKPreviewDimension.dimension3D.rawValue, ignoreSubscriber: nil)
        } else {
            preferenceManager.previewDimension.setIntegerValue(SPLKPreviewDimension.dimension2D.rawValue, ignoreSubscriber: nil)
        }
    }

    override func appMenuManagerDidSelectZoomIn() {
        let manager = preferenceManager
        let currentScale = manager.previewScale.currentDoubleValue
        let targetScale = min(max(currentScale + 0.1, Double(SPLKPreviewMinScale)), Double(SPLKPreviewMaxScale))
        manager.previewScale.setDoubleValue(targetScale, ignoreSubscriber: nil)
    }

    override func appMenuManagerDidSelectZoomOut() {
        let manager = preferenceManager
        let currentScale = manager.previewScale.currentDoubleValue
        let targetScale = min(max(currentScale - 0.1, Double(SPLKPreviewMinScale)), Double(SPLKPreviewMaxScale))
        manager.previewScale.setDoubleValue(targetScale, ignoreSubscriber: nil)
    }

    override func appMenuManagerDidSelectDecreaseInterspace() {
        let manager = preferenceManager
        let currentValue = manager.zInterspace.currentDoubleValue
        let newValue = min(max(currentValue - 0.1, Double(SPLKPreviewMinZInterspace)), Double(SPLKPreviewMaxZInterspace))
        manager.zInterspace.setDoubleValue(newValue, ignoreSubscriber: nil)
    }

    override func appMenuManagerDidSelectIncreaseInterspace() {
        let manager = preferenceManager
        let currentValue = manager.zInterspace.currentDoubleValue
        let newValue = min(max(currentValue + 0.1, Double(SPLKPreviewMinZInterspace)), Double(SPLKPreviewMaxZInterspace))
        manager.zInterspace.setDoubleValue(newValue, ignoreSubscriber: nil)
    }

    override func appMenuManagerDidSelectExpansionIndex(_ index: Int) {
        viewController.hierarchyDataSource.adjustExpansion(byIndex: index, referenceDict: nil)
    }

    override func appMenuManagerDidSelectFilter() {
        viewController.currentHierarchyView().activateSearchBar()
    }
}
