//
//  LKStaticViewController.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/8/4.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import LookinShared

let LKAppShowConsoleNotificationName = Notification.Name("LKAppShowConsoleNotificationName")

final class LKStaticViewController: LKBaseViewController, NSSplitViewDelegate {

    private(set) var viewsPreviewController: LKPreviewController!

    private(set) var progressView: LKProgressIndicatorView!

    var showConsole = false {
        didSet {
            defer { showConsoleObservation.notify() }
            updateConsole()
        }
    }

    private lazy var showConsoleObservation = LKKVOSubject { [unowned self] in self.showConsole }
    var showConsolePublisher: AnyPublisher<Bool, Never> { showConsoleObservation.publisher }

    var isShowingQuickSelectTutorialTips = false
    var isShowingMoveWithSpaceTutorialTips = false

    private var mainSplitView: LKSplitView!
    private var rightSplitView: LKSplitView!
    private var splitTopView: LKBaseView!

    private let imageSyncTipsView = LKTipsView()
    private let tooLargeToSyncScreenshotTipsView = LKRedTipsView()
    private let userConfigNoPreviewTipsView = LKTipsView()
    private let noPreviewTipView = LKTipsView()
    private var tutorialTipView: LKTipsView?
    private let customViewTipView = LKTipsView()
    private let focusTipView = LKYellowTipsView()
    private let fastModeTipView = LKTipsView()

    private var dashboardController: LKDashboardViewController!
    private var hierarchyController: LKStaticHierarchyController!
    private var consoleController: LKConsoleViewController?
    private var measureController: LKMeasureController!

    override func makeContainerView() -> NSView {
        let splitView = LKSplitView()
        splitView.didFinishFirstLayout = { view in
            let x = min(max(350, view.bounds.size.width * 0.3), 700)
            view.setPosition(x, ofDividerAt: 0)
        }
        splitView.arrangesAllSubviews = false
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        mainSplitView = splitView
        return splitView
    }

    override var view: NSView {
        didSet {
            setUp()
        }
    }

    private func setUp() {
        let preferenceManager = LKPreferenceManager.mainManager
        preferenceManager.measureState.subscribe(self) { target, param in
            target.handleMeasureStateChange(param)
        }

        let dataSource = LKStaticHierarchyDataSource.sharedInstance

        hierarchyController = LKStaticHierarchyController(dataSource: dataSource)
        addChild(hierarchyController)
        mainSplitView.addArrangedSubview(hierarchyController.view)

        rightSplitView = LKSplitView()
        rightSplitView.arrangesAllSubviews = true
        rightSplitView.isVertical = false
        rightSplitView.dividerStyle = .thin
        rightSplitView.delegate = self
        mainSplitView.addArrangedSubview(rightSplitView)

        splitTopView = LKBaseView()
        rightSplitView.addArrangedSubview(splitTopView)

        viewsPreviewController = LKPreviewController(dataSource: dataSource)
        viewsPreviewController.staticViewController = self
        splitTopView.addSubview(viewsPreviewController.view)
        addChild(viewsPreviewController)

        dashboardController = LKDashboardViewController(staticDataSource: dataSource)
        splitTopView.addSubview(dashboardController.view)
        addChild(dashboardController)

        measureController = LKMeasureController(dataSource: dataSource)
        measureController.view.isHidden = true
        splitTopView.addSubview(measureController.view)
        addChild(measureController)

        imageSyncTipsView.isHidden = true
        view.addSubview(imageSyncTipsView)

        tooLargeToSyncScreenshotTipsView.image = NSImage(named: "icon_info")
        tooLargeToSyncScreenshotTipsView.title = NSLocalizedString("Image is too large to be displayed.", comment: "")
        tooLargeToSyncScreenshotTipsView.isHidden = true
        view.addSubview(tooLargeToSyncScreenshotTipsView)

        focusTipView.image = NSImage(named: "icon_info")
        focusTipView.title = NSLocalizedString("Currently in focus mode", comment: "")
        focusTipView.isHidden = true
        focusTipView.buttonText = NSLocalizedString("Exit", comment: "")
        focusTipView.clickAction = { [unowned self] _ in
            self.handleExitFocusTipView()
        }
        view.addSubview(focusTipView)

        fastModeTipView.image = NSImage(named: "Icon_Inspiration_small")
        fastModeTipView.title = NSLocalizedString("Fast refresh mode is enabled, which may result in layer consistency issues.", comment: "")
        fastModeTipView.isHidden = true
        fastModeTipView.buttonText = NSLocalizedString("Details", comment: "")
        fastModeTipView.clickAction = { [unowned self] _ in
            self.handleFastModeTipViewClick()
        }
        view.addSubview(fastModeTipView)

        noPreviewTipView.image = NSImage(named: "icon_hide")
        noPreviewTipView.title = NSLocalizedString("The screenshot of selected item is not displayed.", comment: "")
        noPreviewTipView.buttonText = NSLocalizedString("Display", comment: "")
        noPreviewTipView.clickAction = { [unowned self] _ in
            self.handleNoPreviewTipView()
        }
        noPreviewTipView.isHidden = true
        view.addSubview(noPreviewTipView)

        customViewTipView.image = NSImage(named: "Icon_Inspiration_small")
        customViewTipView.title = NSLocalizedString("This object may not be a UIView or CALayer.", comment: "")
        customViewTipView.buttonText = NSLocalizedString("Details", comment: "")
        customViewTipView.clickAction = { _ in
            NSWorkspace.shared.open(URL(string: "https://bytedance.feishu.cn/docx/TRridRXeUoErMTxs94bcnGchnlb")!)
        }
        customViewTipView.isHidden = true
        view.addSubview(customViewTipView)

        userConfigNoPreviewTipsView.image = NSImage(named: "icon_hide")
        userConfigNoPreviewTipsView.title = NSLocalizedString("The screenshot is not displayed due to the config in iOS App.", comment: "")
        userConfigNoPreviewTipsView.buttonText = NSLocalizedString("Details", comment: "")
        userConfigNoPreviewTipsView.clickAction = { _ in
            LKHelper.openCustomConfigWebsite()
        }
        userConfigNoPreviewTipsView.isHidden = true
        view.addSubview(userConfigNoPreviewTipsView)

        progressView = LKProgressIndicatorView()
        view.addSubview(progressView)

        dataSource.selectedItemPublisher
            .sink { [weak self] _ in
                self?.handleSelectItemDidChange()
            }
            .store(in: &cancellables)

        dataSource.selectedItemPublisher.map { _ in () }
            .merge(with: dataSource.itemDidChangeNoPreview)
            .dropFirst()
            .sink { [weak self] in
                guard let self else { return }
                let item = dataSource.selectedItem
                let shouldShowNoPreviewTip = (item?.inNoPreviewHierarchy ?? false) && item?.doNotFetchScreenshotReason != .doNotFetchScreenshotForUserConfig
                if shouldShowNoPreviewTip || !self.noPreviewTipView.isHidden {
                    self.noPreviewTipView.title = String(format: NSLocalizedString("The screenshot of selected %@ is not displayed.", comment: ""), item?.title ?? "(null)")
                    self.noPreviewTipView.bindingObject = item
                    self.noPreviewTipView.isHidden = !shouldShowNoPreviewTip
                    self.view.needsLayout = true
                }
            }
            .store(in: &cancellables)

        dataSource.statePublisher
            .sink { [weak self] state in
                guard let self else { return }
                let isFocus = state == .focus
                self.focusTipView.isHidden = !isFocus
                if isFocus {
                    self.focusTipView.startAnimation()
                } else {
                    self.focusTipView.endAnimation()
                }
                self.view.needsLayout = true
            }
            .store(in: &cancellables)

        LKAppsManager.sharedInstance.inspectingAppPublisher
            .sink { [weak self] app in
                if let app {
                    self?.imageSyncTipsView.setImage(byDeviceType: app.appInfo?.deviceType ?? .simulator)
                }
            }
            .store(in: &cancellables)

        let updateMng = LKStaticAsyncUpdateManager.sharedInstance
        updateMng.modifyingUpdateProgressSignal
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] received, total in
                guard let self else { return }
                let total = max(1, total)
                let progress = CGFloat(received) / CGFloat(total)
                if progress >= 1 {
                    self.progressView.finish(completion: nil)
                    self.imageSyncTipsView.isHidden = true
                } else {
                    self.progressView.animate(toProgress: max(progress, 0.2), duration: 0.1)
                    self.imageSyncTipsView.isHidden = false
                    self.imageSyncTipsView.title = String(format: NSLocalizedString("Updating screenshots… %@ / %@", comment: ""), NSNumber(value: received), NSNumber(value: total))
                    self.view.needsLayout = true
                }
            })
            .store(in: &cancellables)
        updateMng.modifyingUpdateErrorSignal
            .sink { [weak self] error in
                guard let self else { return }
                self.imageSyncTipsView.isHidden = true
                self.progressView.resetToZero()
                LKHelper.alertError(error, window: self.view.window)
            }
            .store(in: &cancellables)
        preferenceManager.fastMode.subscribe(self, sendAtOnce: true) { target, param in
            target.handleFastModeChange(param)
        }

        // Lookin registered this observer on every layout pass, so one notification submitted to the console several
        // times; it is registered once here.
        NotificationCenter.default.publisher(for: LKAppShowConsoleNotificationName)
            .sink { [weak self] notification in
                guard let self else { return }

                let isFirstTimeToShowConsole = self.consoleController == nil
                self.showConsole = true
                let item = notification.object as? LookinDisplayItem
                if isFirstTimeToShowConsole {
                    // give a little time to initialize console
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.consoleController?.submit(withObj: item?.viewObject, text: "self")
                    }
                } else {
                    self.consoleController?.submit(withObj: item?.viewObject, text: "self")
                }
            }
            .store(in: &cancellables)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        dashboardController.view.setWidth(DashboardViewWidth).alignRight(0).fillHeight()
        measureController.view.setWidth(MeasureViewWidth).alignRight(DashboardHorInset).fillHeight()
        viewsPreviewController.view.fillSuperview()

        let windowTitleHeight = LKNavigationManager.sharedInstance.windowTitleBarHeight

        progressView.fillWidth().setHeight(3).setY(windowTitleHeight)

        var tipsY = windowTitleHeight + 10
        let tipsViews: [LKTipsView?] = [connectionTipsView, imageSyncTipsView, tooLargeToSyncScreenshotTipsView, noPreviewTipView, focusTipView, userConfigNoPreviewTipsView, tutorialTipView, customViewTipView, fastModeTipView]
        for tipsView in tipsViews.compactMap({ $0 }).visibleViews {
            let midX = hierarchyController.view.frame.width + (viewsPreviewController.view.frame.width - DashboardViewWidth) / 2.0
            tipsView.fitSize().setY(tipsY).setMidX(midX)
            tipsY = tipsView.frame.maxY + 5
        }
    }

    private func updateConsole() {
        if showConsole {
            let consoleController: LKConsoleViewController
            if let existing = self.consoleController {
                consoleController = existing
            } else {
                consoleController = LKConsoleViewController(hierarchyDataSource: LKStaticHierarchyDataSource.sharedInstance)
                addChild(consoleController)
                self.consoleController = consoleController
            }
            rightSplitView.addArrangedSubview(consoleController.view)

            if consoleController.view.bounds.size.height < 20 {
                DispatchQueue.main.async {
                    self.rightSplitView.setPosition(self.rightSplitView.bounds.size.height - 150, ofDividerAt: 0)
                }
            }
        } else {
            if let consoleView = consoleController?.view, consoleView.superview != nil {
                rightSplitView.removeArrangedSubview(consoleView)
            } else {
                assertionFailure()
            }
        }

        consoleController?.isControllerShowing = showConsole
    }

    /// 获取当前的 hierarchyView
    func currentHierarchyView() -> LKHierarchyView {
        hierarchyController.hierarchyView
    }

    private var dataSource: LKHierarchyDataSource {
        hierarchyController.dataSource
    }

    // MARK: - Tutorial

    func showQuickSelectionTutorialTips() {
        let tutorial = LKTutorialManager.sharedInstance
        tutorial.quickSelection = true
        tutorial.hasAlreadyShowedTipsThisLaunch = true
        isShowingQuickSelectTutorialTips = true
        initTutorialTipsIfNeeded()
        tutorialTipView?.title = NSLocalizedString("While holding \"Command\" key, you can directly select a screenshot without expanding its superview first", comment: "")
        view.needsLayout = true
    }

    func showMoveWithSpaceTutorialTips() {
        let tutorial = LKTutorialManager.sharedInstance
        tutorial.moveWithSpace = true
        tutorial.hasAlreadyShowedTipsThisLaunch = true
        isShowingMoveWithSpaceTutorialTips = true
        initTutorialTipsIfNeeded()
        tutorialTipView?.title = NSLocalizedString("You can move screenshots by holding \"Space\" key and left mouse button", comment: "")
        view.needsLayout = true
    }

    func showNoPreviewTutorialTips() {
        let tutorial = LKTutorialManager.sharedInstance
        tutorial.hasAlreadyShowedTipsThisLaunch = true
        tutorial.togglePreview = true
        initTutorialTipsIfNeeded()
        tutorialTipView?.title = NSLocalizedString("You can hide a screenshot in its right-click menu", comment: "")
        view.needsLayout = true
    }

    func removeTutorialTips() {
        if let tutorialTipView {
            tutorialTipView.removeFromSuperview()
            self.tutorialTipView = nil
            view.needsLayout = true
        }
        isShowingQuickSelectTutorialTips = false
        isShowingMoveWithSpaceTutorialTips = false
    }

    private func initTutorialTipsIfNeeded() {
        if tutorialTipView == nil {
            let tipsView = LKTipsView()
            tipsView.image = NSImage(named: "Icon_Inspiration_small")
            tipsView.buttonText = NSLocalizedString("Do not show again", comment: "")
            tipsView.didClick = { [weak self] tipsView in
                tipsView.removeFromSuperview()
                self?.view.needsLayout = true
            }
            view.addSubview(tipsView)
            tutorialTipView = tipsView
        }
        tutorialTipView?.isHidden = false
    }

    // MARK: - NSSplitViewDelegate

    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        false
    }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if splitView === mainSplitView {
            return HierarchyMinWidth
        } else {
            return splitView.bounds.size.height * 0.3
        }
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if splitView === mainSplitView {
            return max(splitView.bounds.size.width - DashboardViewWidth - 100, HierarchyMinWidth)
        } else {
            return splitView.bounds.size.height - 50
        }
    }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        view.needsLayout = true
    }

    // MARK: - Event Handler

    private func handleNoPreviewTipView() {
        if let item = noPreviewTipView.bindingObject as? LookinDisplayItem {
            hierarchyController.hierarchyView(hierarchyController.hierarchyView, needToShowPreviewOfItem: item)
        } else {
            dataSource.itemDidChangeNoPreview.send(())
        }

        let tutorial = LKTutorialManager.sharedInstance
        if !tutorial.togglePreview {
            guard let selectedRowView = hierarchyController.currentSelectedRowView() else {
                return
            }
            tutorial.showPopover(ofView: selectedRowView, text: "你可在右键菜单里再次隐藏它的图像") {
                LKTutorialManager.sharedInstance.togglePreview = true
                LKTutorialManager.sharedInstance.hasAlreadyShowedTipsThisLaunch = true
            }
        }
    }

    private func handleExitFocusTipView() {
        dataSource.endFocus()
    }

    private func handleFastModeTipViewClick() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: NSLocalizedString("View feature description", comment: "")) { _ in
            NSWorkspace.shared.open(URL(string: "https://qxh1ndiez2w.feishu.cn/wiki/BPihwfigUigWLQk1Epmc5SFenEe")!)
        })

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: NSLocalizedString("Don't remind me again", comment: "")) { [weak self] _ in
            UserDefaults.standard.set(true, forKey: "IgnoreFastModeTips")
            self?.fastModeTipView.isHidden = true
        })

        if let event = NSApplication.shared.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: fastModeTipView.button)
        }
    }

    private func handleMeasureStateChange(_ param: LookinMsgActionParams) {
        let isMeasure = param.integerValue != LookinMeasureState.no.rawValue
        dashboardController.view.isHidden = isMeasure
        measureController.view.isHidden = !isMeasure
    }

    private func handleFastModeChange(_ param: LookinMsgActionParams) {
        if !param.boolValue {
            fastModeTipView.isHidden = true
            return
        }
        let shouldIgnoreTips = UserDefaults.standard.bool(forKey: "IgnoreFastModeTips")
        fastModeTipView.isHidden = shouldIgnoreTips
        view.needsLayout = true
    }

    private func handleSelectItemDidChange() {
        let item = dataSource.selectedItem

        do {
            let showTips = item != nil && item?.appropriateScreenshot == nil && item?.doNotFetchScreenshotReason == .doNotFetchScreenshotForTooLarge
            let shouldHide = !showTips
            if tooLargeToSyncScreenshotTipsView.isHidden != shouldHide {
                tooLargeToSyncScreenshotTipsView.isHidden = shouldHide
                if shouldHide {
                    tooLargeToSyncScreenshotTipsView.endAnimation()
                } else {
                    tooLargeToSyncScreenshotTipsView.startAnimation()
                }
                view.needsLayout = true
            }
        }
        do {
            let showTips = item?.isUserCustom ?? false
            let shouldHide = !showTips
            if customViewTipView.isHidden != shouldHide {
                customViewTipView.isHidden = shouldHide
                view.needsLayout = true
            }
        }
    }

    override var shouldShowConnectionTips: Bool {
        true
    }
}
