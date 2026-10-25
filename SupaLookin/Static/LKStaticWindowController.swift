//
//  LKStaticWindowController.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/4.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import LookinShared

final class LKStaticWindowController: LKWindowController, NSToolbarDelegate, LKStaticAsyncUpdateManagerDelegate {

    let viewController: LKStaticViewController

    private var toolbarItemsMap: [NSToolbarItem.Identifier: NSToolbarItem] = [:]

    /// 当拉取 hierarchy 和更新截图时，该属性为 true
    private var isFetchingHierarchy = false {
        didSet {
            isFetchingHierarchyObservation.notify()
        }
    }
    private var isFetchingDetails = false {
        didSet {
            isFetchingDetailsObservation.notify()
        }
    }

    private lazy var isFetchingHierarchyObservation = LKKVOSubject { [unowned self] in self.isFetchingHierarchy }
    private lazy var isFetchingDetailsObservation = LKKVOSubject { [unowned self] in self.isFetchingDetails }

    private var cancellables = Set<AnyCancellable>()

    init() {
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let window = LKWindow(contentRect: NSRect(x: 0, y: 0, width: screenSize.width * 0.7, height: screenSize.height * 0.7), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: true)
        window.tabbingMode = .disallowed
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: HierarchyMinWidth + DashboardViewWidth + 200, height: 500)
        window.center()
        window.setFrameUsingName(LKWindowSizeName_Static)

        viewController = LKStaticViewController()
        super.init(window: window)

        NotificationCenter.default.publisher(for: LKInspectingAppDidEndNotificationName)
            .sink { [weak self] _ in
                self?.handleInspectingAppDidEnd()
            }
            .store(in: &cancellables)

        window.contentView = viewController.view
        contentViewController = viewController

        let toolbar = NSToolbar()
        toolbar.displayMode = .iconAndLabel
        toolbar.sizeMode = .regular
        toolbar.delegate = self
        window.toolbar = toolbar

        let reloadItem = toolbarItemsMap[LKToolBarIdentifier_Reload]
        let updateManager = LKStaticAsyncUpdateManager.sharedInstance
        updateManager.delegate = self

        isFetchingHierarchyObservation.publisher
            .combineLatest(isFetchingDetailsObservation.publisher)
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] _ in
                guard let self else { return }
                for identifier in [LKToolBarIdentifier_App, LKToolBarIdentifier_Console, LKToolBarIdentifier_FastMode] {
                    let item = self.toolbarItemsMap[identifier]
                    if self.isFetchingHierarchy || self.isFetchingDetails {
                        item?.isEnabled = false
                    } else {
                        item?.isEnabled = true
                    }
                }
            }
            .store(in: &cancellables)
        isFetchingHierarchyObservation.publisher
            .removeDuplicates()
            .sink { isFetching in
                reloadItem?.isEnabled = !isFetching
            }
            .store(in: &cancellables)

        LKStaticHierarchyDataSource.sharedInstance.selectedItemPublisher
            .sink { [weak self] item in
                guard let self else { return }
                let measureButton = self.toolbarItemsMap[LKToolBarIdentifier_Measure]?.view as? NSButton
                let canMeasure = item != nil
                measureButton?.isEnabled = canMeasure
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func popupAllInspectableApps(withSource source: MenuPopoverAppsListControllerEventSource) {
        let appItemView = toolbarItemsMap[LKToolBarIdentifier_App]?.view

        Task { [weak self] in
            let apps = await LKAppsManager.sharedInstance.fetchAppInfos(withImage: true, localInfos: nil)
            guard let self, let appItemView else { return }
            let vc = LKMenuPopoverAppsListController(apps: apps, source: source)
            let popover = NSPopover()
            vc.didSelectApp = { [weak popover] app in
                popover?.close()

                guard let app else { return }
                if let serverVersionError = app.serverVersionError {
                    if serverVersionError.code == LookinErrCode_ServerVersionTooLow {
                        LKHelper.openLookinWebsite(withPath: "faq/server-version-too-low/")
                    } else {
                        LKHelper.openLookinWebsite(withPath: "faq/server-version-too-high/")
                    }

                } else {
                    self.viewController.progressView.animate(toProgress: InitialIndicatorProgressWhenFetchHierarchy)

                    let isTheSameApp = LKAppsManager.sharedInstance.inspectingApp?.appInfo?.isEqual(to: app.appInfo) ?? false

                    Task {
                        do {
                            guard let info = try await app.fetchHierarchyData() else {
                                throw LookinError.inner
                            }
                            self.viewController.progressView.finish(completion: nil)
                            LKAppsManager.sharedInstance.inspectingApp = app
                            LKStaticHierarchyDataSource.sharedInstance.reload(with: info, keepState: isTheSameApp)
                        } catch {
                            LKHelper.alertError(error, window: self.window)
                            self.viewController.progressView.resetToZero()
                        }
                    }
                }
            }

            popover.behavior = .transient
            popover.animates = false
            popover.contentSize = vc.bestSize()
            popover.contentViewController = vc
            popover.show(relativeTo: NSRect(x: 0, y: 0, width: appItemView.bounds.size.width, height: appItemView.bounds.size.height), of: appItemView, preferredEdge: .maxY)
        }
    }

    // MARK: - NSToolbarDelegate

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        var ret = [LKToolBarIdentifier_Reload, LKToolBarIdentifier_FastMode, LKToolBarIdentifier_App, .flexibleSpace, LKToolBarIdentifier_Dimension, LKToolBarIdentifier_Rotation, LKToolBarIdentifier_Setting, .flexibleSpace, LKToolBarIdentifier_Scale, .flexibleSpace, LKToolBarIdentifier_Measure, LKToolBarIdentifier_Console]
        if !LKMessageManager.sharedInstance.queryMessages().isEmpty {
            ret.append(LKToolBarIdentifier_Message)
        }
        return ret
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if let item = toolbarItemsMap[itemIdentifier] {
            return item
        }
        guard let item = LKWindowToolbarHelper.sharedInstance.makeToolBarItem(withIdentifier: itemIdentifier, preferenceManager: LKPreferenceManager.mainManager) else {
            return nil
        }
        toolbarItemsMap[itemIdentifier] = item

        switch item.itemIdentifier {
        case LKToolBarIdentifier_Reload:
            item.onAction { [unowned self] _ in
                self.handleReload()
            }
        case LKToolBarIdentifier_App:
            item.onAction { [unowned self] _ in
                self.handleApp()
            }
        case LKToolBarIdentifier_Rotation:
            item.onAction { _ in
                let boolValue = LKPreferenceManager.mainManager.freeRotation.currentBOOLValue
                LKPreferenceManager.mainManager.freeRotation.setBOOLValue(!boolValue, ignoreSubscriber: nil)
            }
        case LKToolBarIdentifier_Setting:
            item.label = NSLocalizedString("View", comment: "")
            item.onAction { [unowned self] sender in
                if let button = sender as? NSButton {
                    self.handleSetting(button)
                }
            }
        case LKToolBarIdentifier_Console:
            item.onAction { [unowned self] _ in
                self.viewController.showConsole = !self.viewController.showConsole
            }

            viewController.showConsolePublisher
                .removeDuplicates()
                .dropFirst()
                .sink { [weak item] showConsole in
                    (item?.view as? NSButton)?.state = showConsole ? .on : .off
                }
                .store(in: &cancellables)
        case LKToolBarIdentifier_Message:
            item.label = NSLocalizedString("Notifications", comment: "")
            item.onAction { [unowned self] sender in
                if let button = sender as? NSButton {
                    self.handleMessage(button)
                }
            }
        case LKToolBarIdentifier_FastMode:
            item.onAction { _ in
                let boolValue = LKPreferenceManager.mainManager.fastMode.currentBOOLValue
                LKPreferenceManager.mainManager.fastMode.setBOOLValue(!boolValue, ignoreSubscriber: nil)
            }
        default:
            break
        }
        return item
    }

    // MARK: - Event Handler

    private func handleInspectingAppDidEnd() {
        isFetchingHierarchy = false
        isFetchingDetails = false
    }

    private func handleReload() {
        if isFetchingDetails {
            // 停止拉取
            LKStaticAsyncUpdateManager.sharedInstance.endUpdating()
            return
        }

        guard let app = LKAppsManager.sharedInstance.inspectingApp else {
            popupAllInspectableApps(withSource: .reloadButton)
            return
        }

        if isFetchingHierarchy {
            return
        }

        isFetchingHierarchy = true

        viewController.progressView.animate(toProgress: InitialIndicatorProgressWhenFetchHierarchy)

        Task { [weak self] in
            do {
                guard let info = try await app.fetchHierarchyData() else {
                    throw LookinError.inner
                }
                guard let self else { return }
                self.viewController.progressView.finish(completion: nil)
                LKStaticHierarchyDataSource.sharedInstance.reload(with: info, keepState: true)
                self.isFetchingHierarchy = false
            } catch {
                // error
                guard let self else { return }
                self.viewController.progressView.resetToZero()
                self.isFetchingHierarchy = false

                if let window = self.window {
                    NSAlert(error: error).beginSheetModal(for: window, completionHandler: nil)
                }
            }
        }
    }

    private func handleApp() {
        // 停止可能存在的刷新倒计时
        popupAllInspectableApps(withSource: .appButton)
    }

    private func handleSetting(_ button: NSButton) {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = NSSize(width: LKHelper.isEnglish ? 270 : 350, height: 200)
        popover.contentViewController = LKMenuPopoverSettingController(preferenceManager: LKPreferenceManager.mainManager)
        popover.show(relativeTo: NSRect(x: 0, y: 0, width: button.bounds.size.width, height: button.bounds.size.height), of: button, preferredEdge: .maxY)
    }

    private func handleMessage(_ button: NSButton) {
        let menu = NSMenu()

        let msgs = LKMessageManager.sharedInstance.queryMessages()
        for msg in msgs {
            if msg == LKMessage_Jobs {
                let menuItem = NSMenuItem(title: NSLocalizedString("Job openings…(China)", comment: "")) { _ in
                    NSWorkspace.shared.open(URL(string: "https://bytedance.feishu.cn/docx/SAcgdoQuAouyXAxAqy8cmrT2n4b")!)
                    LKMessageManager.sharedInstance.removeMessage(LKMessage_Jobs)
                }
                menuItem.image = NSImage(named: "Icon_Inspiration_small")
                menu.addItem(menuItem)
                menu.addItem(.separator())
                continue
            }

            if msg == LKMessage_NewServerVersion {
                let menuItem = NSMenuItem()
                menuItem.image = NSImage(named: "Icon_Inspiration_small")
                let userVersion = LKAppsManager.sharedInstance.inspectingApp?.appInfo?.serverReadableVersion as String?
                let newestVersion = LKServerVersionRequestor.shared.query() ?? "(null)"
                if let userVersion, !userVersion.isEmpty {
                    let format = NSLocalizedString("Your iOS project uses version %@ of the LookinServer SDK, while the latest version online is %@, it is recommended to upgrade.", comment: "")
                    menuItem.title = String(format: format, userVersion, newestVersion)
                } else {
                    let format = NSLocalizedString("Your iOS project uses an outdated version of the LookinServer SDK. It is recommended to upgrade to the latest version %@", comment: "")
                    menuItem.title = String(format: format, newestVersion)
                }
                menu.addItem(menuItem)

                let historyItem = NSMenuItem(title: NSLocalizedString("Check out version updates on GitHub…", comment: "")) { _ in
                    NSWorkspace.shared.open(URL(string: "https://github.com/QMUI/LookinServer/releases")!)
                }
                historyItem.image = NSImage(size: NSSize(width: 18, height: 1))
                menu.addItem(historyItem)
                menu.addItem(.separator())
                continue
            }

            if msg == LKMessage_SwiftSubspec {
                let menuItem = NSMenuItem()
                menuItem.image = NSImage(named: "Icon_Inspiration_small")
                menuItem.title = NSLocalizedString("Your iOS project seems to use Swift, but you haven't turn on Swift optimization for Lookin", comment: "")
                menu.addItem(menuItem)

                let turnOnItem = NSMenuItem(title: NSLocalizedString("How to turn on…", comment: "")) { _ in
                    NSWorkspace.shared.open(URL(string: "https://bytedance.feishu.cn/docx/GFRLdzpeKoakeyxvwgCcZ5XdnTb")!)
                }
                turnOnItem.image = NSImage(size: NSSize(width: 18, height: 1))
                menu.addItem(turnOnItem)
                menu.addItem(.separator())
                continue
            }
        }

        if menu.numberOfItems == 0 {
            let menuItem = NSMenuItem()
            menuItem.title = NSLocalizedString("No message", comment: "")
            menu.addItem(menuItem)
        }

        if let event = NSApplication.shared.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: button)
        }
    }

    // MARK: - LKAppMenuManagerDelegate

    override var supportedAppMenuActions: Set<LKAppMenuAction> {
        Set(LKAppMenuAction.allCases)
    }

    override func appMenuManagerDidSelectReload() {
        if isFetchingHierarchy {
            return
        }
        if isFetchingDetails {
            let error = LookinError.make(NSLocalizedString("Cannot reload at this time", comment: ""), NSLocalizedString("Please wait until current sync is completed. You can get sync progress in the upper-left corner of this window.", comment: ""))
            if let window {
                NSAlert(error: error).beginSheetModal(for: window, completionHandler: nil)
            }
            return
        }
        handleReload()
    }

    override func appMenuManagerDidSelectDimension() {
        let manager = LKPreferenceManager.mainManager
        if manager.previewDimension.currentIntegerValue == LookinPreviewDimension.dimension2D.rawValue {
            manager.previewDimension.setIntegerValue(LookinPreviewDimension.dimension3D.rawValue, ignoreSubscriber: nil)
        } else {
            manager.previewDimension.setIntegerValue(LookinPreviewDimension.dimension2D.rawValue, ignoreSubscriber: nil)
        }
    }

    override func appMenuManagerDidSelectZoomIn() {
        let manager = LKPreferenceManager.mainManager
        let currentScale = manager.previewScale.currentDoubleValue
        let targetScale = min(max(currentScale + 0.1, Double(LookinPreviewMinScale)), Double(LookinPreviewMaxScale))
        manager.previewScale.setDoubleValue(targetScale, ignoreSubscriber: nil)
    }

    override func appMenuManagerDidSelectZoomOut() {
        let manager = LKPreferenceManager.mainManager
        let currentScale = manager.previewScale.currentDoubleValue
        let targetScale = min(max(currentScale - 0.1, Double(LookinPreviewMinScale)), Double(LookinPreviewMaxScale))
        manager.previewScale.setDoubleValue(targetScale, ignoreSubscriber: nil)
    }

    override func appMenuManagerDidSelectDecreaseInterspace() {
        let manager = LKPreferenceManager.mainManager
        let currentValue = manager.zInterspace.currentDoubleValue
        let newValue = min(max(currentValue - 0.1, Double(LookinPreviewMinZInterspace)), Double(LookinPreviewMaxZInterspace))
        manager.zInterspace.setDoubleValue(newValue, ignoreSubscriber: nil)
    }

    override func appMenuManagerDidSelectIncreaseInterspace() {
        let manager = LKPreferenceManager.mainManager
        let currentValue = manager.zInterspace.currentDoubleValue
        let newValue = min(max(currentValue + 0.1, Double(LookinPreviewMinZInterspace)), Double(LookinPreviewMaxZInterspace))
        manager.zInterspace.setDoubleValue(newValue, ignoreSubscriber: nil)
    }

    override func appMenuManagerDidSelectExpansionIndex(_ index: Int) {
        LKStaticHierarchyDataSource.sharedInstance.adjustExpansion(byIndex: index, referenceDict: nil)

        let tutorial = LKTutorialManager.sharedInstance
        if !tutorial.hasAlreadyShowedTipsThisLaunch && !tutorial.quickSelection && index <= 1 {
            viewController.showQuickSelectionTutorialTips()
        }
    }

    override func appMenuManagerDidSelectExport() {
        let exportManager = LKExportManager.sharedInstance
        let hierarchyInfo = LKStaticHierarchyDataSource.sharedInstance.rawHierarchyInfo

        var fileName: String?
        var exportedData: Data?

        let accessoryView = LKExportAccessoryView()
        accessoryView.fitSize()
        // Lookin kept this subscription for the app's lifetime; it ends with the save panel here.
        let compressionObservation = LKPreferenceManager.mainManager.preferredExportCompressionPublisher
            .sink { compression in
                (exportedData, fileName) = exportManager.data(from: hierarchyInfo, imageCompression: compression)
                accessoryView.dataSize = exportedData?.count ?? 0
            }

        let panel = NSSavePanel()
        panel.accessoryView = accessoryView
        panel.nameFieldStringValue = fileName ?? ""
        panel.allowsOtherFileTypes = false
        panel.allowedContentTypes = [.init(filenameExtension: "lookin") ?? .data]
        panel.isExtensionHidden = true
        panel.canCreateDirectories = true
        guard let window else { return }
        panel.beginSheetModal(for: window) { result in
            compressionObservation.cancel()
            if result == .OK {
                guard let url = panel.url else { return }
                guard let exportedData else {
                    assertionFailure("LookinClient - write fail, no data")
                    return
                }
                do {
                    try exportedData.write(to: url)
                } catch {
                    NSLog("LookinClient - write fail:%@", String(describing: error))
                }
            }
        }
    }

    override func appMenuManagerDidSelectOpenInNewWindow() {
        let newHierarchyInfo = LKStaticHierarchyDataSource.sharedInstance.rawHierarchyInfo?.copy() as? LookinHierarchyInfo
        let file = LookinHierarchyFile()
        file.serverVersion = newHierarchyInfo?.serverVersion ?? 0
        file.hierarchyInfo = newHierarchyInfo
        LKNavigationManager.sharedInstance.showReader(withHierarchyFile: file, title: nil)
    }

    override func appMenuManagerDidSelectFilter() {
        viewController.currentHierarchyView().activateSearchBar()
    }

    // MARK: - LKStaticAsyncUpdateManagerDelegate

    func detailUpdateTasks(totalCount: Int, finishedCount: Int) {
        let reloadItem = toolbarItemsMap[LKToolBarIdentifier_Reload]
        let reloadButton = reloadItem?.view as? NSButton

        let isFetching = totalCount > finishedCount

        if isFetching {
            if isFetchingDetails {
                // 继续维持 fetch 状态
            } else {
                // 进入 fetch 状态
                isFetchingDetails = true

                let image = NSImage(named: "icon_stop")
                image?.isTemplate = true
                reloadButton?.image = image
            }
            reloadItem?.label = "\(finishedCount) / \(totalCount)"

        } else {
            if isFetchingDetails {
                // 退出 fetch 状态
                isFetchingDetails = false
                reloadItem?.label = NSLocalizedString("Reload", comment: "")

                let image = NSImage(named: "icon_reload")
                image?.isTemplate = true
                reloadButton?.image = image
            } else {
                // 继续维持“非 fetch”状态
            }
        }
    }

    func detailUpdateReceivedError(_ error: Error) {
        LKHelper.alertError(error, window: window)
    }
}
