//
//  SPLKPreviewController.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/8/6.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import SPLKServer

final class SPLKPreviewController: SPLKBaseViewController, NSGestureRecognizerDelegate, SPLKPreviewStageViewDelegate, NSMenuDelegate {

    weak var staticViewController: SPLKStaticViewController?

    private let dataSource: SPLKHierarchyDataSource
    private let stageView = SPLKPreviewStageView()
    private let previewView: SPLKPreviewView
    private let clickRecognizer = NSClickGestureRecognizer()
    private let panRecognizer = SPLKPreviewPanGestureRecognizer()
    private let doubleClickRecognizer = NSClickGestureRecognizer()
    private let rightClickRecognizer = NSClickGestureRecognizer()
    private let rightClickMenu = NSMenu()
    private var rightClickingDisplayItem: SPLKDisplayItem?
    private var monitors = SPLKEventMonitors()
    private var hasLayouted = false
    private var prevRotation: CGPoint = .zero
    private var prevRawHierarchyInfo: SPLKHierarchyInfo?

    /// 按住 space 时可以通过 pan 来移动图像
    private var isKeyingDownSpace = false {
        didSet {
            if let window = view.window {
                window.invalidateCursorRects(for: view)
            }
            doubleClickRecognizer.isEnabled = !isKeyingDownSpace
            rightClickRecognizer.isEnabled = !isKeyingDownSpace
        }
    }

    /// 按住 command 时可以穿透选择，以及通过 scroll 鼠标来放大缩小图像
    private var isKeyingDownCommand = false {
        didSet {
            if isKeyingDownCommand && view.window?.isKeyWindow == true {
                dataSource.preferenceManager.isQuickSelecting.setBOOLValue(true, ignoreSubscriber: nil)
            } else {
                dataSource.preferenceManager.isQuickSelecting.setBOOLValue(false, ignoreSubscriber: nil)
            }
        }
    }

    /// 按住 option 时可以测距
    private var isKeyingDownOption = false {
        didSet {
            guard oldValue != isKeyingDownOption else { return }

            if dataSource.preferenceManager.measureState.currentIntegerValue == SPLKMeasureState.locked.rawValue {
                return
            }

            let state: SPLKMeasureState
            if isKeyingDownOption && dataSource.selectedItem != nil && view.window?.isKeyWindow == true {
                state = .unlocked
            } else {
                state = .no
            }
            dataSource.preferenceManager.measureState.setIntegerValue(state.rawValue, ignoreSubscriber: nil)
        }
    }

    init(dataSource: SPLKHierarchyDataSource) {
        self.dataSource = dataSource
        previewView = SPLKPreviewView(dataSource: dataSource)
        super.init(containerView: nil)

        let appInfo = dataSource.rawHierarchyInfo?.appInfo

        previewView.preferenceManager = dataSource.preferenceManager
        previewView.alphaValue = 0
        previewView.appScreenSize = CGSize(width: appInfo?.screenWidth ?? 0, height: appInfo?.screenHeight ?? 0)
        previewView.showHiddenItems = dataSource.preferenceManager.showHiddenItems.currentBOOLValue
        dataSource.preferenceManager.showHiddenItems.subscribe(self) { controller, param in
            controller.previewView.showHiddenItems = param.boolValue
            controller.previewView.updateZPosition()
        }
        stageView.didChangeAppearanceBlock = { [weak self] _, isDarkMode in
            self?.previewView.isDarkMode = isDarkMode
        }
        view.addSubview(previewView)

        // Just(()) 让渲染立即执行一次
        Just(())
            .merge(with: dataSource.didReloadHierarchyInfo, dataSource.itemDidChangeNoPreview)
            .sink { [weak self] in
                guard let self else { return }
                let validItems = dataSource.flatItems.filter { obj in
                    if obj.inNoPreviewHierarchy {
                        return false
                    }
                    if let customInfo = obj.customInfo {
                        return customInfo.hasValidFrame()
                    }
                    return true
                }
                self.previewView.render(withDisplayItems: validItems, discardCache: true)
            }
            .store(in: &cancellables)

        dataSource.didReloadFlatItemsWithSearchOrFocus
            .sink { [weak self] in
                let validItems = dataSource.flatItems.filter { !$0.inNoPreviewHierarchy }
                self?.previewView.render(withDisplayItems: validItems, discardCache: false)
            }
            .store(in: &cancellables)

        var signalsToUpdateZIndex: [AnyPublisher<Void, Never>] = [dataSource.displayingFlatItemsPublisher.map { _ in () }.eraseToAnyPublisher()]
        if let staticDataSource = dataSource as? SPLKStaticHierarchyDataSource {
            signalsToUpdateZIndex.append(staticDataSource.itemDidChangeHiddenAlphaValue.map { _ in () }.eraseToAnyPublisher())
            signalsToUpdateZIndex.append(staticDataSource.itemsDidChangeFrame.map { _ in () }.eraseToAnyPublisher())
        }
        Publishers.MergeMany(signalsToUpdateZIndex)
            .dropFirst()
            .sink { [weak self] in
                self?.previewView.updateZPosition()
            }
            .store(in: &cancellables)

        panRecognizer.onAction { [weak self] recognizer in
            self?.handlePanGesture(recognizer)
        }
        panRecognizer.delegate = self
        previewView.addGestureRecognizer(panRecognizer)

        clickRecognizer.onAction { [weak self] recognizer in
            self?.handleClickGesture(recognizer)
        }
        clickRecognizer.numberOfClicksRequired = 1
        clickRecognizer.delegate = self
        previewView.addGestureRecognizer(clickRecognizer)

        doubleClickRecognizer.onAction { [weak self] recognizer in
            self?.handleDoubleClick(recognizer)
        }
        doubleClickRecognizer.numberOfClicksRequired = 2
        previewView.addGestureRecognizer(doubleClickRecognizer)

        rightClickRecognizer.onAction { [weak self] recognizer in
            self?.handleRightClick(recognizer)
        }
        rightClickRecognizer.buttonMask = 0x2
        rightClickRecognizer.numberOfClicksRequired = 1
        previewView.addGestureRecognizer(rightClickRecognizer)

        rightClickMenu.autoenablesItems = false
        rightClickMenu.delegate = self

        monitors.add(NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            // 在 macbook 上，按下 space 然后通过触摸板拖拽然后松开 space，此时 keyUp 方法不会被调到，不知道为啥，这里做个兜底
            if let self, event.type == .keyUp, event.charactersIgnoringModifiers == " " {
                self.isKeyingDownSpace = false
                self.view.window?.invalidateCursorRects(for: self.view)
            }
            return event
        })
        monitors.add(NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            self.isKeyingDownCommand = event.modifierFlags.contains(.command)
            self.isKeyingDownOption = event.modifierFlags.contains(.option)
            return event
        })

        let preferenceManager = dataSource.preferenceManager
        preferenceManager.previewScale.subscribe(self, sendAtOnce: true) { controller, params in
            controller.previewView.scale = params.doubleValue
        }
        preferenceManager.previewDimension.subscribe(self, sendAtOnce: true) { controller, params in
            controller.handleManagerPreviewDimensionDidChange(params)
        }
        preferenceManager.freeRotation.subscribe(self, sendAtOnce: true) { controller, params in
            controller.handleManagerFreeRotationDidChange(params)
        }
        preferenceManager.zInterspace.subscribe(self, sendAtOnce: true) { controller, params in
            controller.previewView.zInterspace = params.doubleValue
        }

        // 用于在 reload app 时重置 translation 和 scale
        dataSource.rawHierarchyInfoPublisher
            .dropFirst()
            .sink { [weak self] _ in
                self?.hierarchyInfoDidChange()
            }
            .store(in: &cancellables)

        dataSource.selectedItemPublisher
            .sink { [weak self] item in
                self?.previewView.didSelectItem(item)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)
            .sink { [weak self] note in
                guard let self, note.object as? NSWindow === self.view.window else { return }
                self.isKeyingDownSpace = false
                self.isKeyingDownOption = false
                self.isKeyingDownCommand = false
            }
            .store(in: &cancellables)
    }

    override func makeContainerView() -> NSView {
        stageView.didChangeAppearanceBlock = { view, isDarkMode in
            view.backgroundColor = isDarkMode ? NSColor(splkRed: 0, green: 0, blue: 0) : NSColor(splkRed: 255, green: 255, blue: 255)
        }
        stageView.delegate = self
        return stageView
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        // 向左多延伸一个 dashboard 的视觉宽度（由于一般向右旋转，所以少延伸个 20 似乎更好看一点），向下多延伸一个 titleBar 高度，从而让 preview 在视觉上居中
        let titleBarHeight = SPLKNavigationManager.sharedInstance.windowTitleBarHeight
        previewView.setWidth(view.frame.width + DashboardViewWidth - DashboardHorInset - 20).alignRight(0).setHeight(view.frame.height + titleBarHeight).setY(0)

        if !hasLayouted {
            hasLayouted = true

            // 做一个开场动画
            previewView.setRotation(CGPoint(x: 0.8, y: 0), animated: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 1
                    self.previewView.animator().alphaValue = 1
                }
                self.previewView.setRotation(CGPoint(x: 0.6, y: 0), animated: true, timingFunction: CAMediaTimingFunction(controlPoints: 0.3, 0.93, 0.26, 0.88), duration: 1.5)
            }
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(self)
    }

    // MARK: - NSGestureRecognizerDelegate

    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldAttemptToRecognizeWith event: NSEvent) -> Bool {
        #if DEBUG
        if gestureRecognizer === clickRecognizer {
            if event.locationInWindow.y <= 25 {
                // 点击底部的 debug 按钮
                return false
            }
        }
        #endif
        if gestureRecognizer === panRecognizer {
            if previewView.dimension != .dimension3D && !isKeyingDownSpace {
                // 没有 isKeyingDownSpace 说明此时手势目的是旋转，而此时视图又不是 3D，因此直接拒绝该手势
                return false
            }
        }
        return true
    }

    // MARK: - SPLKPreviewStageViewDelegate

    func previewStageView(_ view: SPLKPreviewStageView, mouseMoved event: NSEvent) {
        if isKeyingDownSpace {
            if dataSource.hoveredItem != nil {
                dataSource.hoveredItem = nil
            }
            return
        }
        guard let window = self.view.window, let contentView = window.contentView else {
            return
        }
        var rawPoint = event.locationInWindow
        rawPoint.y = window.frame.size.height - rawPoint.y
        let targetView = contentView.hitTest(rawPoint)
        if targetView !== previewView {
            return
        }

        let point = previewView.convert(rawPoint, from: contentView)
        let item = previewView.displayItem(at: point)
        if dataSource.hoveredItem !== item {
            dataSource.hoveredItem = item
        }
    }

    func didResetCursorRects(in view: SPLKPreviewStageView) {
        if isKeyingDownSpace {
            view.addCursorRect(self.view.bounds, cursor: .openHand)
        }
    }

    // MARK: - Event

    private func handleManagerFreeRotationDidChange(_ params: SPLKMsgActionParams) {
        let canFreeRotate = params.boolValue
        if canFreeRotate {
            if previewView.dimension == .dimension3D {
                var rotation = previewView.rotation
                rotation.y = -0.05
                previewView.setRotation(rotation, animated: true)
            }
        } else {
            var rotation = previewView.rotation
            if rotation.y == 0 {
                return
            }
            rotation.y = 0
            previewView.setRotation(rotation, animated: true)
        }
    }

    private func handleManagerPreviewDimensionDidChange(_ params: SPLKMsgActionParams) {
        guard let newDimension = SPLKPreviewDimension(rawValue: params.integerValue) else {
            return
        }
        if previewView.dimension == newDimension {
            return
        }

        if newDimension == .dimension2D {
            prevRotation = previewView.rotation
            previewView.setDimension(newDimension, animated: true)
        } else {
            var rotation = prevRotation
            previewView.setDimension(newDimension, animated: true)

            // 避免之前的 rotation 太小而感知不到 2D / 3D 的切换
            if rotation.x >= 0 {
                rotation.x = max(0.18, rotation.x)
            } else {
                rotation.x = min(-0.18, rotation.x)
            }

            if !dataSource.preferenceManager.freeRotation.currentBOOLValue {
                rotation.y = 0
            }

            previewView.setRotation(rotation, animated: true)
        }
    }

    private func handlePanGesture(_ recognizer: SPLKPreviewPanGestureRecognizer) {
        if recognizer.state == .began {
            SPLKUserActionManager.sharedInstance.sendAction(.previewOperation)

            // 停止可能正在编辑的 card 输入框
            view.window?.makeFirstResponder(self)

            if isKeyingDownSpace {
                recognizer.purpose = .translate

                if let staticViewController, staticViewController.isShowingMoveWithSpaceTutorialTips {
                    staticViewController.removeTutorialTips()
                }
            } else {
                recognizer.purpose = .rotate
            }
            recognizer.initialRotation = previewView.rotation
            recognizer.initialTranslation = previewView.translation

        } else if recognizer.state == .changed {
            let translation = recognizer.translation(in: view)
            if recognizer.purpose == .rotate {
                if previewView.dimension != .dimension3D {
                    return
                }
                let newRotationX = recognizer.initialRotation.x + translation.x * 0.01
                let newRotationY: CGFloat
                if dataSource.preferenceManager.freeRotation.currentBOOLValue {
                    newRotationY = recognizer.initialRotation.y + translation.y * 0.004
                } else {
                    newRotationY = 0
                }
                previewView.setRotation(CGPoint(x: newRotationX, y: newRotationY), animated: false)

            } else if recognizer.purpose == .translate {
                SPLKTutorialManager.sharedInstance.moveWithSpace = true
                if staticViewController?.isShowingMoveWithSpaceTutorialTips == true {
                    staticViewController?.removeTutorialTips()
                }

                let initialTranslation = recognizer.initialTranslation
                // 我们希望随着 scale 的变大，translation 的比率逐渐变小，避免图像被放大到很大的时候轻轻一滑就滑走了
                // currentScale 范围是 0 ~ 1，factor 被相应映射为 1 ~ 0.1
                let currentScale = previewView.scale
                let factor = (1 - currentScale) * 0.92 + 0.08
                previewView.translation = NSPoint(x: initialTranslation.x + translation.x * 0.01 * factor, y: initialTranslation.y - translation.y * 0.01 * factor)
            }
        }
    }

    private func handleClickGesture(_ recognizer: NSClickGestureRecognizer) {
        if dataSource.shouldAvoidChangingPreviewSelectionDueToDashboardSearch {
            return
        }

        SPLKUserActionManager.sharedInstance.sendAction(.previewOperation)

        // 停止可能正在编辑的 card 输入框
        view.window?.makeFirstResponder(self)

        let point = recognizer.location(in: previewView)
        let item = previewView.displayItem(at: point)

        if dataSource.selectedItem === item {
            return
        }
        // 注意这里要先 expand 然后再 select 以使得可以滚动到目标位置
        if let item, !item.displayingInHierarchy {
            SPLKTutorialManager.sharedInstance.quickSelection = true
            if let staticViewController, staticViewController.isShowingQuickSelectTutorialTips {
                staticViewController.removeTutorialTips()
            }

            dataSource.expandToShowItem(item)
        }

        dataSource.selectedItem = item

        let tutorial = SPLKTutorialManager.sharedInstance
        if !tutorial.hasAlreadyShowedTipsThisLaunch && !tutorial.togglePreview {
            let parsedRotation = (previewView.rotation.x * 180.0) / .pi
            if (parsedRotation > 75 && parsedRotation < 100) || (parsedRotation < -75 && parsedRotation > -100) {
                tutorial.togglePreview = true
                tutorial.hasAlreadyShowedTipsThisLaunch = true
                staticViewController?.showNoPreviewTutorialTips()
            }
        }
    }

    private func handleRightClick(_ recognizer: NSClickGestureRecognizer) {
        SPLKUserActionManager.sharedInstance.sendAction(.previewOperation)
        // 停止可能正在编辑的 card 输入框
        view.window?.makeFirstResponder(self)

        let point = recognizer.location(in: previewView)
        guard let item = previewView.displayItem(at: point), item.displayingInHierarchy else {
            return
        }

        if dataSource.selectedItem !== item {
            dataSource.selectedItem = item
        }

        rightClickingDisplayItem = item
        rightClickMenu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func handleDoubleClick(_ recognizer: NSClickGestureRecognizer) {
        SPLKUserActionManager.sharedInstance.sendAction(.previewOperation)
        // 停止可能正在编辑的 card 输入框
        view.window?.makeFirstResponder(self)

        let point = recognizer.location(in: previewView)
        guard let item = previewView.displayItem(at: point), item.displayingInHierarchy else {
            return
        }

        let hasShowedAsk = SPLKPreferenceManager.popupToAskDoubleClickBehaviorIfNeeded(with: view.window)
        if hasShowedAsk {
            return
        }
        switch SPLKPreferenceManager.mainManager.doubleClickBehavior {
        case .collapse:
            if item.isExpandable {
                if item.isExpanded {
                    dataSource.collapseItem(item)
                } else {
                    dataSource.expandItem(item)
                }
            }
        case .focus:
            dataSource.focusDisplayItem(item)
        }
    }

    override func magnify(with event: NSEvent) {
        super.magnify(with: event)
        if event.phase == .changed {
            let manager = dataSource.preferenceManager
            var targetScale = manager.previewScale.currentDoubleValue + event.magnification * 0.3
            targetScale = max(min(targetScale, 1), 0)
            manager.previewScale.setDoubleValue(targetScale, ignoreSubscriber: nil)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        if isKeyingDownCommand {
            let manager = dataSource.preferenceManager
            let currentScale = manager.previewScale.currentDoubleValue
            var targetScale = currentScale - event.deltaY * 0.005
            targetScale = max(min(targetScale, SPLKPreviewMaxScale), SPLKPreviewMinScale)
            manager.previewScale.setDoubleValue(targetScale, ignoreSubscriber: nil)

        } else {
            // 我们希望随着 scale 的变大，translation 的比率逐渐变小，避免图像被放大到很大的时候轻轻一滑就滑走了
            // currentScale 范围是 0 ~ 1，factor 被相应映射为 1 ~ 0.3
            let currentScale = previewView.scale
            let factor = (1 - currentScale) * 0.7 + 0.3

            var translation = previewView.translation
            translation.x += event.deltaX * 0.04 * factor
            translation.y -= event.deltaY * 0.04 * factor
            previewView.translation = translation

            let tutorial = SPLKTutorialManager.sharedInstance
            if let staticViewController, !tutorial.hasAlreadyShowedTipsThisLaunch && !tutorial.moveWithSpace {
                tutorial.moveWithSpace = true
                staticViewController.showMoveWithSpaceTutorialTips()
            }
        }
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " {
            isKeyingDownSpace = true
            return
        }
        if dataSource.keyDown(event) {
            return
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " {
            isKeyingDownSpace = false
            return
        }
        super.keyUp(with: event)
    }

    private func hierarchyInfoDidChange() {
        guard let currentInfo = dataSource.rawHierarchyInfo else {
            assertionFailure()
            return
        }

        previewView.appScreenSize = CGSize(width: currentInfo.appInfo?.screenWidth ?? 0, height: currentInfo.appInfo?.screenHeight ?? 0)

        let prevInfo = prevRawHierarchyInfo
        prevRawHierarchyInfo = currentInfo
        guard let prevInfo else {
            return
        }
        let prevWidth = prevInfo.appInfo?.screenWidth ?? 0
        let prevHeight = prevInfo.appInfo?.screenHeight ?? 0
        let currentWidth = currentInfo.appInfo?.screenWidth ?? 0
        let currentHeight = currentInfo.appInfo?.screenHeight ?? 0

        if prevWidth == currentWidth && prevHeight == currentHeight {
            // 内容尺寸没有变化
            return
        }
        // iOS App 尺寸变化，重置 Scale
        dataSource.preferenceManager.previewScale.setDoubleValue(Double(SPLKInitialPreviewScale), ignoreSubscriber: nil)
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        guard let displayItem = rightClickingDisplayItem else {
            return
        }

        if !displayItem.isUserCustom {
            menu.addItem(NSMenuItem(title: NSLocalizedString("Focus", comment: "")) { [weak self] _ in
                guard let self, let item = self.rightClickingDisplayItem else { return }
                self.dataSource.focusDisplayItem(item)
            })
            menu.addItem(NSMenuItem(title: NSLocalizedString("Print", comment: "")) { [weak self] _ in
                NotificationCenter.default.post(name: SPLKAppShowConsoleNotificationName, object: self?.rightClickingDisplayItem)
            })
            menu.addItem(.separator())

            if !dataSource.isReadOnly {
                let isUpdating = SPLKStaticAsyncUpdateManager.sharedInstance.isUpdating
                let reloadItem = NSMenuItem()
                reloadItem.title = NSLocalizedString("Reload layer", comment: "")
                if !isUpdating {
                    reloadItem.onAction { [weak self] _ in
                        guard let item = self?.rightClickingDisplayItem else { return }
                        SPLKStaticAsyncUpdateManager.sharedInstance.reloadSingleDisplayItem(item)
                    }
                }
                menu.addItem(reloadItem)
                let reloadChildrenItem = NSMenuItem()
                reloadChildrenItem.title = NSLocalizedString("Reload layer and its children", comment: "")
                if !isUpdating {
                    reloadChildrenItem.onAction { [weak self] _ in
                        guard let item = self?.rightClickingDisplayItem else { return }
                        SPLKStaticAsyncUpdateManager.sharedInstance.reloadDisplayItemAndChildren(item)
                    }
                }
                menu.addItem(reloadChildrenItem)
                menu.addItem(.separator())
            }
        }

        if displayItem.isExpandable {
            if displayItem.isExpanded {
                menu.addItem(NSMenuItem(title: NSLocalizedString("Collapse children", comment: "")) { [weak self] _ in
                    guard let self, let item = self.rightClickingDisplayItem else { return }
                    self.dataSource.collapseAllChildren(of: item)
                })
            } else {
                menu.addItem(NSMenuItem(title: NSLocalizedString("Expand recursively", comment: "")) { [weak self] _ in
                    guard let self, let item = self.rightClickingDisplayItem else { return }
                    self.dataSource.expandItemsRooted(by: item)
                })
            }
            menu.addItem(.separator())
        }

        let cancelPreviewItem = NSMenuItem(title: NSLocalizedString("Hide screenshot this time", comment: "")) { [weak self] _ in
            SPLKTutorialManager.sharedInstance.togglePreview = true
            guard let self else { return }
            self.rightClickingDisplayItem?.noPreview = true
            self.dataSource.itemDidChangeNoPreview.send(())
        }
        cancelPreviewItem.isEnabled = true
        menu.addItem(cancelPreviewItem)

        if !displayItem.isUserCustom && displayItem.groupScreenshot != nil {
            menu.addItem(NSMenuItem(title: NSLocalizedString("Hide screenshot forever…", comment: "")) { _ in
                SPLKHelper.openCustomConfigWebsite()
            })
            menu.addItem(.separator())

            let exportItem = NSMenuItem(title: NSLocalizedString("Export screenshot…", comment: "")) { [weak self] _ in
                SPLKExportManager.exportScreenshot(with: self?.rightClickingDisplayItem)
            }
            exportItem.isEnabled = true
            menu.addItem(exportItem)

            let copyItem = NSMenuItem()
            copyItem.title = NSLocalizedString("Copy as PNG", comment: "")
            copyItem.submenu = copyAsPNGSubmenu(with: displayItem)
            menu.addItem(copyItem)
        }
    }

    private func copyAsPNGSubmenu(with displayItem: SPLKDisplayItem) -> NSMenu {
        let nativeScale = SPLKExportManager.nativeScale(for: displayItem)
        let submenu = NSMenu()
        for scale in 1...3 {
            let pixelSize = SPLKExportManager.pixelSize(for: displayItem, scale: scale)
            let item = NSMenuItem(title: String(format: "%ldx (%ldx%ld)", scale, lround(pixelSize.width), lround(pixelSize.height))) { item in
                guard let displayItem = item.representedObject as? SPLKDisplayItem else { return }
                SPLKExportManager.copyScreenshotAsPNG(with: displayItem, scale: item.tag)
            }
            item.representedObject = displayItem
            item.tag = scale
            item.isEnabled = scale <= nativeScale
            submenu.addItem(item)
        }
        return submenu
    }

    func menuDidClose(_ menu: NSMenu) {
        // 按住 cmd 键激活右键菜单，然后松开 cmd，然后关闭菜单，这时 eventMonitor 不会捕捉到 cmd 被松开，所以要在这里弥补一下
        isKeyingDownCommand = NSEvent.modifierFlags.contains(.command)
    }
}

/// Removes its local event monitors when released, which the Objective-C controller did in dealloc.
final class SPLKEventMonitors {

    // Only touched on the main actor; deinit, which is nonisolated, runs there too.
    nonisolated(unsafe) private var monitors: [Any] = []

    func add(_ monitor: Any?) {
        if let monitor {
            monitors.append(monitor)
        }
    }

    deinit {
        let monitors = self.monitors
        MainActor.assumeIsolated {
            monitors.forEach { NSEvent.removeMonitor($0) }
        }
    }
}
