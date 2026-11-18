//
//  SPLKStaticWindowController.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/4.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import SPLKServer

final class SPLKStaticWindowController: SPLKWindowController, NSToolbarDelegate, SPLKStaticAsyncUpdateManagerDelegate {

    let viewController: SPLKStaticViewController

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

    private lazy var isFetchingHierarchyObservation = SPLKKVOSubject { [unowned self] in self.isFetchingHierarchy }
    private lazy var isFetchingDetailsObservation = SPLKKVOSubject { [unowned self] in self.isFetchingDetails }

    private var cancellables = Set<AnyCancellable>()

    private let modeItem = SPLKModeToolbarItem()
    private weak var modeSession: SPLKDeviceSession?
    private var arbiterSubscription: AnyCancellable?
    // Set when the app drops out of Live Control. A device's first screen capture makes it re-attach over USB, which
    // drops the app; Live Control comes back if the app reconnects by itself before this.
    private var resumeLiveControlDeadline: Date?
    private weak var resumeLiveControlSession: SPLKDeviceSession?
    private var liveControlStartDate: Date?
    // A drop this soon after Live Control starts is the device re-attaching for screen capture, so it's expected.
    private static let expectedDropWindow: TimeInterval = 15
    private var reconnectToast: SPLKToast?
    private static let resumeLiveControlWindow: TimeInterval = 30

    private var isShowingVideo: Bool {
        viewController.modeTransition.displayedMode.showsVideo
    }

    init() {
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let window = SPLKWindow(contentRect: NSRect(x: 0, y: 0, width: screenSize.width * 0.7, height: screenSize.height * 0.7), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: true)
        window.tabbingMode = .disallowed
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: HierarchyMinWidth + DashboardViewWidth + 200, height: 500)
        window.center()
        window.setFrameUsingName(SPLKWindowSizeName_Static)

        viewController = SPLKStaticViewController()
        super.init(window: window)

        NotificationCenter.default.publisher(for: SPLKInspectingAppDidEndNotificationName)
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

        let updateManager = SPLKStaticAsyncUpdateManager.sharedInstance
        updateManager.delegate = self

        isFetchingHierarchyObservation.publisher
            .combineLatest(isFetchingDetailsObservation.publisher)
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateToolbarEnablement()
            }
            .store(in: &cancellables)

        SPLKStaticHierarchyDataSource.sharedInstance.selectedItemPublisher
            .sink { [weak self] _ in
                self?.updateToolbarEnablement()
            }
            .store(in: &cancellables)

        setUpModes()
    }

    // MARK: - Modes

    private func setUpModes() {
        let transition = viewController.modeTransition
        transition.onModeChange = { [weak self] _ in
            self?.updateToolbarEnablement()
        }
        transition.reloadHierarchy = { [weak self] in
            guard let self, let app = SPLKAppsManager.sharedInstance.inspectingApp, !self.isFetchingHierarchy else { return nil }
            self.isFetchingHierarchy = true
            self.viewController.progressView.animate(toProgress: InitialIndicatorProgressWhenFetchHierarchy)
            let error = await self.fetchHierarchy(from: app)
            if let error, let window = self.window {
                NSAlert(error: error).beginSheetModal(for: window, completionHandler: nil)
            }
            return error
        }
        modeItem.onSelect = { [weak self] choice in
            self?.select(choice)
        }
        SPLKAppsManager.sharedInstance.inspectingAppPublisher
            .sink { [weak self] app in
                self?.inspectingSessionDidChange(app?.session)
            }
            .store(in: &cancellables)
        SPLKAppsManager.sharedInstance.didAutoReconnectSucc
            .sink { [weak self] _ in
                self?.resumeLiveControlIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func inspectingSessionDidChange(_ session: SPLKDeviceSession?) {
        guard session !== modeSession else { return }
        if session == nil, modeSession != nil, viewController.modeTransition.displayedMode == .liveControl {
            resumeLiveControlDeadline = Date().addingTimeInterval(Self.resumeLiveControlWindow)
            if let start = liveControlStartDate, Date().timeIntervalSince(start) < Self.expectedDropWindow {
                reconnectToast = SPLKToast.show(NSLocalizedString("Switching the device to screen capture…", comment: ""), detail: NSLocalizedString("The device reconnects the first time its screen is captured. Live Control comes back by itself.", comment: ""), in: window, duration: Self.resumeLiveControlWindow)
            }
        } else if let session {
            // Resumes only if this is the app's own reconnect, which didAutoReconnectSucc then confirms.
            resumeLiveControlSession = (resumeLiveControlDeadline.map { Date() < $0 } ?? false) ? session : nil
            resumeLiveControlDeadline = nil
            if resumeLiveControlSession == nil {
                reconnectToast?.dismiss()
                reconnectToast = nil
            }
        }
        if modeSession != nil, viewController.modeTransition.displayedMode.showsVideo {
            // The app went away or was replaced; there's nothing to animate back from.
            viewController.modeTransition.show(.inspect, session: nil, animated: false)
        }
        modeSession = session
        arbiterSubscription = session?.arbiter.modeSubject
            .removeDuplicates()
            .sink { [weak self, weak session] mode in
                self?.arbiterModeDidChange(SPLKWindowMode(mode), session: session)
            }
        updateModeItem()
    }

    private func resumeLiveControlIfNeeded() {
        guard let session = resumeLiveControlSession, session === modeSession else { return }
        resumeLiveControlSession = nil
        reconnectToast?.dismiss()
        reconnectToast = nil
        guard session.arbiter.mode == .inspect else { return }
        select(.liveControl)
    }

    private func arbiterModeDidChange(_ mode: SPLKWindowMode, session: SPLKDeviceSession?) {
        liveControlStartDate = mode == .liveControl ? Date() : nil
        viewController.modeTransition.show(mode, session: session, animated: true)
        updateModeItem()
    }

    private func updateModeItem() {
        let mode = modeSession.map { SPLKWindowMode($0.arbiter.mode) } ?? .inspect
        modeItem.update(mode: mode, hasApp: modeSession != nil)
    }

    private func select(_ choice: SPLKModeToolbarItem.Choice) {
        guard let arbiter = modeSession?.arbiter else { return }
        Task { [weak self] in
            switch choice {
            case .inspect:
                await arbiter.stopLiveControl()
            case .liveControl:
                do {
                    try await arbiter.startLiveControl()
                } catch {
                    SPLKHelper.alertError(SPLKDeviceSession.translate(error), window: self?.window)
                }
            case .endTakeover:
                await arbiter.takeBack()
            }
        }
    }

    // Video modes leave only the mode menu; Inspect's items follow the sync state as before.
    private func updateToolbarEnablement() {
        let video = isShowingVideo
        let isFetching = isFetchingHierarchy || isFetchingDetails
        for (identifier, item) in toolbarItemsMap where identifier != SPLKToolBarIdentifier_Mode {
            let enabled: Bool
            switch identifier {
            case SPLKToolBarIdentifier_App, SPLKToolBarIdentifier_Console, SPLKToolBarIdentifier_FastMode:
                enabled = !video && !isFetching
            case SPLKToolBarIdentifier_Reload:
                enabled = !video && !isFetchingHierarchy
            case SPLKToolBarIdentifier_Measure:
                enabled = !video && SPLKStaticHierarchyDataSource.sharedInstance.selectedItem != nil
            default:
                enabled = !video
            }
            item.isEnabled = enabled
            (item.view as? NSControl)?.isEnabled = enabled
            if let scaleView = item.view as? SPLKWindowToolbarScaleView {
                scaleView.slider.isEnabled = enabled
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func popupAllInspectableApps(withSource source: MenuPopoverAppsListControllerEventSource) {
        let appItemView = toolbarItemsMap[SPLKToolBarIdentifier_App]?.view

        Task { [weak self] in
            let apps = await SPLKAppsManager.sharedInstance.fetchAppInfos(withImage: true, localInfos: nil)
            guard let self, let appItemView else { return }
            let vc = SPLKMenuPopoverAppsListController(apps: apps, source: source)
            let popover = NSPopover()
            vc.didSelectApp = { [weak popover] app in
                popover?.close()

                guard let app else { return }
                if let serverVersionError = app.serverVersionError {
                    if serverVersionError.code == SPLKErrCode_ServerVersionTooLow {
                        SPLKHelper.openLookinWebsite(withPath: "faq/server-version-too-low/")
                    } else {
                        SPLKHelper.openLookinWebsite(withPath: "faq/server-version-too-high/")
                    }

                } else {
                    Task {
                        do {
                            try await self.select(app)
                        } catch {
                            SPLKHelper.alertError(error, window: self.window)
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
        var ret = [SPLKToolBarIdentifier_Mode, SPLKToolBarIdentifier_Reload, SPLKToolBarIdentifier_FastMode, SPLKToolBarIdentifier_App, .flexibleSpace, SPLKToolBarIdentifier_Dimension, SPLKToolBarIdentifier_Rotation, SPLKToolBarIdentifier_Setting, .flexibleSpace, SPLKToolBarIdentifier_Scale, .flexibleSpace, SPLKToolBarIdentifier_Measure, SPLKToolBarIdentifier_Console]
        if !SPLKMessageManager.sharedInstance.queryMessages().isEmpty {
            ret.append(SPLKToolBarIdentifier_Message)
        }
        return ret
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if let item = toolbarItemsMap[itemIdentifier] {
            return item
        }
        if itemIdentifier == SPLKToolBarIdentifier_Mode {
            toolbarItemsMap[itemIdentifier] = modeItem
            return modeItem
        }
        guard let item = SPLKWindowToolbarHelper.sharedInstance.makeToolBarItem(withIdentifier: itemIdentifier, preferenceManager: SPLKPreferenceManager.mainManager) else {
            return nil
        }
        toolbarItemsMap[itemIdentifier] = item

        switch item.itemIdentifier {
        case SPLKToolBarIdentifier_Reload:
            item.onAction { [unowned self] _ in
                self.handleReload()
            }
        case SPLKToolBarIdentifier_App:
            item.onAction { [unowned self] _ in
                self.handleApp()
            }
        case SPLKToolBarIdentifier_Rotation:
            item.onAction { _ in
                let boolValue = SPLKPreferenceManager.mainManager.freeRotation.currentBOOLValue
                SPLKPreferenceManager.mainManager.freeRotation.setBOOLValue(!boolValue, ignoreSubscriber: nil)
            }
        case SPLKToolBarIdentifier_Setting:
            item.label = NSLocalizedString("View", comment: "")
            item.onAction { [unowned self] sender in
                if let button = sender as? NSButton {
                    self.handleSetting(button)
                }
            }
        case SPLKToolBarIdentifier_Console:
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
        case SPLKToolBarIdentifier_Message:
            item.label = NSLocalizedString("Notifications", comment: "")
            item.onAction { [unowned self] sender in
                if let button = sender as? NSButton {
                    self.handleMessage(button)
                }
            }
        case SPLKToolBarIdentifier_FastMode:
            item.onAction { _ in
                let boolValue = SPLKPreferenceManager.mainManager.fastMode.currentBOOLValue
                SPLKPreferenceManager.mainManager.fastMode.setBOOLValue(!boolValue, ignoreSubscriber: nil)
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
            SPLKStaticAsyncUpdateManager.sharedInstance.endUpdating()
            return
        }

        guard let app = SPLKAppsManager.sharedInstance.inspectingApp else {
            popupAllInspectableApps(withSource: .reloadButton)
            return
        }

        if isFetchingHierarchy {
            return
        }

        isFetchingHierarchy = true

        viewController.progressView.animate(toProgress: InitialIndicatorProgressWhenFetchHierarchy)

        Task { [weak self] in
            if let error = await self?.fetchHierarchy(from: app), let window = self?.window {
                NSAlert(error: error).beginSheetModal(for: window, completionHandler: nil)
            }
        }
    }

    private func fetchHierarchy(from app: SPLKInspectableApp) async -> Error? {
        do {
            guard let info = try await app.fetchHierarchyData() else {
                throw SPLKError.inner
            }
            viewController.progressView.finish(completion: nil)
            SPLKStaticHierarchyDataSource.sharedInstance.reload(with: info, keepState: true)
            isFetchingHierarchy = false
            return nil
        } catch {
            // error
            viewController.progressView.resetToZero()
            isFetchingHierarchy = false
            return error
        }
    }

    // Unlike Reload in the menu, MCP's reload never alerts, and never stops a detail sync that's running
    // Picking an app in the toolbar's list, which MCP's select_app does too.
    func select(_ app: SPLKInspectableApp) async throws {
        viewController.progressView.animate(toProgress: InitialIndicatorProgressWhenFetchHierarchy)
        let isTheSameApp = SPLKAppsManager.sharedInstance.inspectingApp?.appInfo?.isEqual(to: app.appInfo) ?? false
        do {
            guard let info = try await app.fetchHierarchyData() else {
                throw SPLKError.inner
            }
            viewController.progressView.finish(completion: nil)
            SPLKAppsManager.sharedInstance.inspectingApp = app
            SPLKStaticHierarchyDataSource.sharedInstance.reload(with: info, keepState: isTheSameApp)
        } catch {
            viewController.progressView.resetToZero()
            throw error
        }
    }

    func reloadForMCP() async throws {
        guard let app = SPLKAppsManager.sharedInstance.inspectingApp else {
            throw SPLKError.noConnect
        }
        if isFetchingHierarchy || isFetchingDetails {
            throw SPLKError.make("The hierarchy is syncing.", "Try again once Supa Lookin finishes syncing.")
        }
        isFetchingHierarchy = true
        viewController.progressView.animate(toProgress: InitialIndicatorProgressWhenFetchHierarchy)
        if let error = await fetchHierarchy(from: app) {
            throw error
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
        popover.contentSize = NSSize(width: SPLKHelper.isEnglish ? 270 : 350, height: 200)
        popover.contentViewController = SPLKMenuPopoverSettingController(preferenceManager: SPLKPreferenceManager.mainManager)
        popover.show(relativeTo: NSRect(x: 0, y: 0, width: button.bounds.size.width, height: button.bounds.size.height), of: button, preferredEdge: .maxY)
    }

    private func handleMessage(_ button: NSButton) {
        let menu = NSMenu()

        let msgs = SPLKMessageManager.sharedInstance.queryMessages()
        for msg in msgs {
            if msg == SPLKMessage_Jobs {
                let menuItem = NSMenuItem(title: NSLocalizedString("Job openings…(China)", comment: "")) { _ in
                    NSWorkspace.shared.open(URL(string: "https://bytedance.feishu.cn/docx/SAcgdoQuAouyXAxAqy8cmrT2n4b")!)
                    SPLKMessageManager.sharedInstance.removeMessage(SPLKMessage_Jobs)
                }
                menuItem.image = NSImage(named: "Icon_Inspiration_small")
                menu.addItem(menuItem)
                menu.addItem(.separator())
                continue
            }

            if msg == SPLKMessage_NewServerVersion {
                let menuItem = NSMenuItem()
                menuItem.image = NSImage(named: "Icon_Inspiration_small")
                let userVersion = SPLKAppsManager.sharedInstance.inspectingApp?.appInfo?.serverReadableVersion as String?
                let newestVersion = SPLK_SERVER_READABLE_VERSION
                if let userVersion, !userVersion.isEmpty {
                    let format = NSLocalizedString("Your iOS project uses version %@ of SPLKServer, while this Supa Lookin ships with %@. It is recommended to upgrade.", comment: "")
                    menuItem.title = String(format: format, userVersion, newestVersion)
                } else {
                    let format = NSLocalizedString("Your iOS project uses an outdated version of SPLKServer. It is recommended to upgrade to version %@", comment: "")
                    menuItem.title = String(format: format, newestVersion)
                }
                menu.addItem(menuItem)

                let historyItem = NSMenuItem(title: NSLocalizedString("Check out version updates on GitHub…", comment: "")) { _ in
                    NSWorkspace.shared.open(URL(string: "https://github.com/weirui-kong/SupaLookin/releases")!)
                }
                historyItem.image = NSImage(size: NSSize(width: 18, height: 1))
                menu.addItem(historyItem)
                menu.addItem(.separator())
                continue
            }

            if msg == SPLKMessage_SwiftSubspec {
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

    // MARK: - SPLKAppMenuManagerDelegate

    override var supportedAppMenuActions: Set<SPLKAppMenuAction> {
        let modeActions: Set<SPLKAppMenuAction> = [.inspectMode, .liveControlMode, .endTakeover, .shake, .home, .lock]
        var actions = isShowingVideo ? [] : Set(SPLKAppMenuAction.allCases).subtracting(modeActions)
        switch modeSession?.arbiter.mode {
        case .inspect:
            actions.formUnion([.inspectMode, .liveControlMode])
        case .liveControl:
            actions.formUnion([.inspectMode, .liveControlMode])
            switch modeSession?.inputAvailability.value {
            case .host:
                actions.formUnion([.shake, .home, .lock])
            case .app:
                actions.insert(.shake)
            default:
                break
            }
        case .takeover:
            actions.insert(.endTakeover)
        case nil:
            break
        }
        return actions
    }

    override var checkedAppMenuActions: Set<SPLKAppMenuAction> {
        switch modeSession?.arbiter.mode {
        case .inspect: return [.inspectMode]
        case .liveControl: return [.liveControlMode]
        default: return []
        }
    }

    override func appMenuManagerDidSelectModeAction(_ action: SPLKAppMenuAction) {
        switch action {
        case .inspectMode: select(.inspect)
        case .liveControlMode: select(.liveControl)
        case .endTakeover: select(.endTakeover)
        case .shake: viewController.liveController.shake()
        case .home: viewController.liveController.press(.home)
        case .lock: viewController.liveController.press(.lock)
        default: break
        }
    }

    override func appMenuManagerDidSelectReload() {
        if isFetchingHierarchy {
            return
        }
        if isFetchingDetails {
            let error = SPLKError.make(NSLocalizedString("Cannot reload at this time", comment: ""), NSLocalizedString("Please wait until current sync is completed. You can get sync progress in the upper-left corner of this window.", comment: ""))
            if let window {
                NSAlert(error: error).beginSheetModal(for: window, completionHandler: nil)
            }
            return
        }
        handleReload()
    }

    override func appMenuManagerDidSelectDimension() {
        let manager = SPLKPreferenceManager.mainManager
        if manager.previewDimension.currentIntegerValue == SPLKPreviewDimension.dimension2D.rawValue {
            manager.previewDimension.setIntegerValue(SPLKPreviewDimension.dimension3D.rawValue, ignoreSubscriber: nil)
        } else {
            manager.previewDimension.setIntegerValue(SPLKPreviewDimension.dimension2D.rawValue, ignoreSubscriber: nil)
        }
    }

    override func appMenuManagerDidSelectZoomIn() {
        let manager = SPLKPreferenceManager.mainManager
        let currentScale = manager.previewScale.currentDoubleValue
        let targetScale = min(max(currentScale + 0.1, Double(SPLKPreviewMinScale)), Double(SPLKPreviewMaxScale))
        manager.previewScale.setDoubleValue(targetScale, ignoreSubscriber: nil)
    }

    override func appMenuManagerDidSelectZoomOut() {
        let manager = SPLKPreferenceManager.mainManager
        let currentScale = manager.previewScale.currentDoubleValue
        let targetScale = min(max(currentScale - 0.1, Double(SPLKPreviewMinScale)), Double(SPLKPreviewMaxScale))
        manager.previewScale.setDoubleValue(targetScale, ignoreSubscriber: nil)
    }

    override func appMenuManagerDidSelectDecreaseInterspace() {
        let manager = SPLKPreferenceManager.mainManager
        let currentValue = manager.zInterspace.currentDoubleValue
        let newValue = min(max(currentValue - 0.1, Double(SPLKPreviewMinZInterspace)), Double(SPLKPreviewMaxZInterspace))
        manager.zInterspace.setDoubleValue(newValue, ignoreSubscriber: nil)
    }

    override func appMenuManagerDidSelectIncreaseInterspace() {
        let manager = SPLKPreferenceManager.mainManager
        let currentValue = manager.zInterspace.currentDoubleValue
        let newValue = min(max(currentValue + 0.1, Double(SPLKPreviewMinZInterspace)), Double(SPLKPreviewMaxZInterspace))
        manager.zInterspace.setDoubleValue(newValue, ignoreSubscriber: nil)
    }

    override func appMenuManagerDidSelectExpansionIndex(_ index: Int) {
        SPLKStaticHierarchyDataSource.sharedInstance.adjustExpansion(byIndex: index, referenceDict: nil)

        let tutorial = SPLKTutorialManager.sharedInstance
        if !tutorial.hasAlreadyShowedTipsThisLaunch && !tutorial.quickSelection && index <= 1 {
            viewController.showQuickSelectionTutorialTips()
        }
    }

    override func appMenuManagerDidSelectExport() {
        let exportManager = SPLKExportManager.sharedInstance
        let hierarchyInfo = SPLKStaticHierarchyDataSource.sharedInstance.rawHierarchyInfo

        var fileName: String?
        var exportedData: Data?

        let accessoryView = SPLKExportAccessoryView()
        accessoryView.fitSize()
        // Lookin kept this subscription for the app's lifetime; it ends with the save panel here.
        let compressionObservation = SPLKPreferenceManager.mainManager.preferredExportCompressionPublisher
            .sink { compression in
                (exportedData, fileName) = exportManager.data(from: hierarchyInfo, imageCompression: compression)
                accessoryView.dataSize = exportedData?.count ?? 0
            }

        let panel = NSSavePanel()
        panel.accessoryView = accessoryView
        panel.nameFieldStringValue = fileName ?? ""
        panel.allowsOtherFileTypes = false
        panel.allowedContentTypes = [.init(filenameExtension: SPLKDocument.fileExtension) ?? .data]
        panel.isExtensionHidden = true
        panel.canCreateDirectories = true
        guard let window else { return }
        panel.beginSheetModal(for: window) { result in
            compressionObservation.cancel()
            if result == .OK {
                guard let url = panel.url else { return }
                guard let exportedData else {
                    assertionFailure("SPLKClient - write fail, no data")
                    return
                }
                do {
                    try exportedData.write(to: url)
                } catch {
                    NSLog("SPLKClient - write fail:%@", String(describing: error))
                }
            }
        }
    }

    override func appMenuManagerDidSelectOpenInNewWindow() {
        let newHierarchyInfo = SPLKStaticHierarchyDataSource.sharedInstance.rawHierarchyInfo?.copy() as? SPLKHierarchyInfo
        let file = SPLKHierarchyFile()
        file.serverVersion = newHierarchyInfo?.serverVersion ?? 0
        file.hierarchyInfo = newHierarchyInfo
        SPLKNavigationManager.sharedInstance.showReader(withHierarchyFile: file, title: nil)
    }

    override func appMenuManagerDidSelectFilter() {
        viewController.currentHierarchyView().activateSearchBar()
    }

    // MARK: - SPLKStaticAsyncUpdateManagerDelegate

    func detailUpdateTasks(totalCount: Int, finishedCount: Int) {
        let reloadItem = toolbarItemsMap[SPLKToolBarIdentifier_Reload]
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
        SPLKHelper.alertError(error, window: window)
    }
}
