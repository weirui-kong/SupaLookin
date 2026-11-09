//
//  SPLKDashboardViewController.swift
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

final class SPLKDashboardViewController: SPLKBaseViewController, SPLKDashboardCardViewDelegate, SPLKDashboardHeaderViewDelegate, SPLKDashboardSearchPropViewDelegate, SPLKDashboardSearchMethodsViewDelegate {

    private var scrollView: NSScrollView!
    private var documentView: SPLKBaseView!
    private var cardContainerView: SPLKBaseView!

    private var groupList: [SPLKAttributesGroup] = []
    private var cardViews: [String: SPLKDashboardCardView] = [:]

    private var searchContainerView: SPLKBaseView!
    private var headerView: SPLKDashboardHeaderView!
    private var searchPropViews: [SPLKDashboardSearchPropView] = []
    private var searchMethodsView: SPLKDashboardSearchMethodsView?
    private var methodsDataSource: SPLKDashboardSearchMethodsDataSource?

    private var staticDataSource: SPLKStaticHierarchyDataSource?
    private var readDataSource: SPLKReadHierarchyDataSource?

    private(set) var isStaticMode = false

    init(staticDataSource dataSource: SPLKStaticHierarchyDataSource) {
        super.init(containerView: nil)
        staticDataSource = dataSource
        isStaticMode = true
        didInitialized()
    }

    init(readDataSource dataSource: SPLKReadHierarchyDataSource) {
        super.init(containerView: nil)
        readDataSource = dataSource
        isStaticMode = false
        didInitialized()
    }

    override func makeContainerView() -> NSView {
        let containerView = SPLKBaseView()

        documentView = SPLKBaseView()

        scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.contentView.documentView = documentView
        containerView.addSubview(scrollView)

        headerView = SPLKDashboardHeaderView()
        headerView.delegate = self
        documentView.addSubview(headerView)

        cardContainerView = SPLKBaseView()
        documentView.addSubview(cardContainerView)

        searchContainerView = SPLKBaseView()
        searchContainerView.isHidden = true
        documentView.addSubview(searchContainerView)

        return containerView
    }

    private func didInitialized() {
        cardViews = [:]
        searchPropViews = []

        // RAC's deliverOnMainThread always dispatched asynchronously, so does receive(on:) here.
        if let staticDataSource {
            staticDataSource.selectedItemPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    self.reload(withGroupList: staticDataSource.selectedItem?.queryAllAttrGroupList())
                }
                .store(in: &cancellables)

            staticDataSource.itemDidChangeAttrGroup
                .receive(on: DispatchQueue.main)
                .sink { [weak self] displayItem in
                    guard let self else { return }
                    if staticDataSource.selectedItem === displayItem {
                        self.reload(withGroupList: displayItem.queryAllAttrGroupList())
                    }
                }
                .store(in: &cancellables)

            let methodsDataSource = SPLKDashboardSearchMethodsDataSource()
            self.methodsDataSource = methodsDataSource
            staticDataSource.didReloadHierarchyInfo
                .sink { _ in
                    methodsDataSource.clearAllCache()
                }
                .store(in: &cancellables)

        } else if let readDataSource {
            readDataSource.selectedItemPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    self.reload(withGroupList: readDataSource.selectedItem?.queryAllAttrGroupList())
                }
                .store(in: &cancellables)
        }

        NotificationCenter.default.publisher(for: NotificationName_DidChangeSectionShowing)
            .sink { [weak self] _ in
                guard let self else { return }
                self.reload(withGroupList: self.currentDataSource()?.selectedItem?.queryAllAttrGroupList())
            }
            .store(in: &cancellables)
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        scrollView.fillSuperview()

        let verMargin: CGFloat = 10
        let contentWidth = DashboardViewWidth - DashboardHorInset * 2

        headerView.setWidth(contentWidth).setX(DashboardHorInset).setHeight(23).setY(10)

        if !cardContainerView.isHidden {
            cardContainerView.setWidth(contentWidth).setX(DashboardHorInset).setY(headerView.frame.maxY + verMargin)

            var y: CGFloat = 0
            for group in groupList {
                if let view = cardViews[group.uniqueKey()], !view.isHidden {
                    view.setWidth(contentWidth).setY(y).fitHeight()
                    y = view.frame.maxY + verMargin
                }
            }

            cardContainerView.setHeight(y)
            documentView.fillWidth().setY(0).extendToMaxY(cardContainerView.frame.maxY)
        }

        if !searchContainerView.isHidden {
            searchContainerView.setWidth(contentWidth).setX(DashboardHorInset).setY(headerView.frame.maxY + verMargin)

            var y: CGFloat = 0
            for view in searchPropViews where !view.isHidden {
                view.setWidth(contentWidth).setX(0).fitHeight().setY(y)
                y = view.frame.maxY + verMargin
            }

            if let searchMethodsView, searchMethodsView.isVisible {
                searchMethodsView.setWidth(contentWidth).setY(y).fitHeight()
                y = searchMethodsView.frame.maxY
            }

            searchContainerView.setHeight(y)
            documentView.fillWidth().setY(0).extendToMaxY(searchContainerView.frame.maxY)
        }
    }

    private func reload(withGroupList list: [SPLKAttributesGroup]?) {
        let list = list ?? []
        groupList = list

        if !list.isEmpty {
            scrollView.isHidden = false
        } else {
            scrollView.isHidden = true
            return
        }

        var needlessViews = Array(cardViews.values)

        for group in list {
            let cardView: SPLKDashboardCardView
            if let existing = cardViews[group.uniqueKey()] {
                cardView = existing
                needlessViews.removeAll { $0 === cardView }
            } else {
                cardView = SPLKDashboardCardView()
                cardView.dashboardViewController = self
                cardView.delegate = self
                cardViews[group.uniqueKey()] = cardView
                cardContainerView.addSubview(cardView)
            }
            cardView.isHidden = false
            cardView.attrGroup = group
            cardView.isCollapsed = SPLKPreferenceManager.mainManager.collapsedAttrGroups.contains(group.identifier)
            cardView.render()
        }

        needlessViews.forEach { $0.isHidden = true }

        view.needsLayout = true
    }

    func modifyAttribute(_ attribute: SPLKAttribute, newValue: Any?) async throws {
        if attribute.isUserCustom() {
            try await modifyCustomAttribute(attribute, newValue: newValue)
        } else {
            try await modifyInbuiltAttribute(attribute, newValue: newValue)
        }
    }

    private func modifyCustomAttribute(_ attribute: SPLKAttribute, newValue: Any?) async throws {
        let modification = SPLKCustomAttrModification()
        modification.customSetterID = attribute.customSetterID
        modification.attrType = attribute.attrType
        modification.value = newValue

        if (modification.customSetterID ?? "").isEmpty {
            assertionFailure()
            SPLKHelper.alertError(SPLKError.inner, window: view.window)
            throw SPLKError.inner
        }

        guard let inspectingApp = SPLKAppsManager.sharedInstance.inspectingApp else {
            SPLKHelper.alertError(SPLKError.noConnect, window: view.window)
            throw SPLKError.noConnect
        }

        do {
            _ = try await inspectingApp.submitCustomModification(modification)
            NSLog("custom modification - succ")
            attribute.value = newValue
        } catch {
            SPLKHelper.alertError(error, window: view.window)
            throw error
        }
    }

    private func modifyInbuiltAttribute(_ attribute: SPLKAttribute, newValue: Any?) async throws {
        let modifyingItem = attribute.targetDisplayItem

        let modification = SPLKAttributeModification()
        modification.clientReadableVersion = SPLKHelper.splkReadableVersion
        if SPLKDashboardBlueprint.isUIViewProperty(withAttrID: attribute.identifier) {
            modification.targetOid = modifyingItem?.viewObject?.oid ?? 0
        } else {
            modification.targetOid = modifyingItem?.layerObject?.oid ?? 0
        }
        modification.setterSelector = SPLKDashboardBlueprint.setter(withAttrID: attribute.identifier)
        modification.attrType = attribute.attrType
        modification.value = newValue

        // Lookin reported these two errors yet still submitted the modification; here they end it.
        if modification.setterSelector == nil {
            assertionFailure()
            SPLKHelper.alertError(SPLKError.inner, window: view.window)
            throw SPLKError.inner
        }

        guard let inspectingApp = SPLKAppsManager.sharedInstance.inspectingApp else {
            SPLKHelper.alertError(SPLKError.noConnect, window: view.window)
            throw SPLKError.noConnect
        }

        do {
            let detail = try await inspectingApp.submitInbuiltModification(modification) as? SPLKDisplayItemDetail
            NSLog("modification - succ")
            if let staticDataSource {
                SPLKDashboardTextControlEditingFlag.sharedInstance.shouldIgnoreTextEditingChangeEvent = true
                // 用户通过回车键触发 endEditing -> 触发编辑 -> 走到这里 -> 这一句会触发 reload -> reload 触发 cardView removeFromSuperview -> 再次触发 editEditing，因此会导致连续修改两次（多 sync 一次图像数据），所以这里用标记位规避一下，懒得琢磨其它办法了
                staticDataSource.modify(with: detail)
                SPLKDashboardTextControlEditingFlag.sharedInstance.shouldIgnoreTextEditingChangeEvent = false

                if SPLKDashboardBlueprint.needPatchAfterModification(withAttrID: attribute.identifier) {
                    SPLKStaticAsyncUpdateManager.sharedInstance.updateAfterModifyingDisplayItem(modifyingItem)
                }

            } else {
                assertionFailure()
            }
        } catch {
            SPLKHelper.alertError(error, window: view.window)
            throw error
        }
    }

    func currentDataSource() -> SPLKHierarchyDataSource? {
        if let staticDataSource {
            return staticDataSource
        }
        if let readDataSource {
            return readDataSource
        }
        assertionFailure()
        return nil
    }

    // MARK: - SPLKDashboardCardViewDelegate

    func dashboardCardViewNeedToggleCollapse(_ view: SPLKDashboardCardView) {
        guard let manager = currentDataSource()?.preferenceManager, let identifier = view.attrGroup?.identifier else { return }
        if manager.collapsedAttrGroups.contains(identifier) {
            view.isCollapsed = false
            manager.collapsedAttrGroups = manager.collapsedAttrGroups.filter { $0 != identifier }
        } else {
            view.isCollapsed = true
            manager.collapsedAttrGroups = manager.collapsedAttrGroups + [identifier]
        }
        self.view.needsLayout = true
    }

    // MARK: - SPLKDashboardHeaderViewDelegate

    func dashboardHeaderView(_ view: SPLKDashboardHeaderView, didInputString searchString: String) {
        if searchString.utf16.count < 3 {
            searchContainerView.isHidden = true
            return
        }

        let searchString = searchString.lowercased()

        // 以下是在渲染 attrs

        var resultAttrs: [SPLKAttribute] = []
        for group in currentDataSource()?.selectedItem?.queryAllAttrGroupList() ?? [] {
            for section in group.attrSections ?? [] {
                for attr in section.attributes ?? [] {
                    let title: String?
                    if attr.isUserCustom() {
                        title = attr.displayTitle
                    } else {
                        title = SPLKDashboardBlueprint.fullTitle(withAttrID: attr.identifier)
                    }
                    if title?.lowercased().contains(searchString) == true {
                        resultAttrs.append(attr)
                    }
                }
            }
        }

        searchPropViews.dequeue(count: resultAttrs.count, add: { _ in
            let view = SPLKDashboardSearchPropView()
            view.delegate = self
            self.searchContainerView.addSubview(view)
            return view
        }, notDequeued: { _, view in
            view.isHidden = true
        }, doNext: { idx, view in
            view.render(withAttribute: resultAttrs[idx])
            view.isHidden = false
        })

        // 以下是在渲染 methods

        if currentDataSource() !== staticDataSource {
            searchContainerView.isHidden = false
            searchMethodsView?.isHidden = true
            self.view.needsLayout = true
            return
        }

        let searchMethodsView: SPLKDashboardSearchMethodsView
        if let existing = self.searchMethodsView {
            searchMethodsView = existing
        } else {
            searchMethodsView = SPLKDashboardSearchMethodsView()
            searchMethodsView.delegate = self
            searchContainerView.addSubview(searchMethodsView)
            self.searchMethodsView = searchMethodsView
        }

        let selectedItem = currentDataSource()?.selectedItem
        let selectedObj = selectedItem?.viewObject ?? selectedItem?.layerObject
        let selectedClassName = selectedObj?.rawClassName()
        Task { [weak self] in
            do {
                let methodsList = try await self?.methodsDataSource?.fetchNonArgMethodsList(withClass: selectedClassName)
                guard let self else { return }
                if searchString != self.headerView.currentInputString() {
                    return
                }
                let searchedMethods = SPLKHelper.bestMatches(in: methodsList ?? [], input: searchString, maxResultsCount: 5)
                searchMethodsView.render(withMethods: searchedMethods, oid: selectedObj?.oid ?? 0)
                self.searchContainerView.isHidden = false
                self.view.needsLayout = true

            } catch {
                guard let self else { return }
                if searchString != self.headerView.currentInputString() {
                    return
                }
                searchMethodsView.render(withError: error)
                self.searchContainerView.isHidden = false
                self.view.needsLayout = true
            }
        }
    }

    func dashboardHeaderView(_ view: SPLKDashboardHeaderView, didToggleActive isActive: Bool) {
        if isActive {
            cardContainerView.animator().isHidden = true
            currentDataSource()?.shouldAvoidChangingPreviewSelectionDueToDashboardSearch = true

        } else {
            cardContainerView.animator().isHidden = false
            searchContainerView.animator().isHidden = true
            self.view.needsLayout = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                // 这个 0.25 的延时是关键，想象这个场景：用户想要结束搜索于是点击了空白图像处，此时程序会先走到这里的 resignActive 逻辑，然后再走到 preview 那边的取消图层选中逻辑（这两者时差大概在 0.1s 左右），但此时用户应该是并不想取消图层选中的，所以这里要用一个 flag 保护一下这种情况
                if !view.isActive {
                    self.currentDataSource()?.shouldAvoidChangingPreviewSelectionDueToDashboardSearch = false
                }
            }
        }
    }

    // MARK: - SPLKDashboardSearchMethodsViewDelegate

    func dashboardSearchMethodsView(_ view: SPLKDashboardSearchMethodsView, requestToInvokeMethod method: String, oid: UInt) {
        Task { [weak self] in
            do {
                let value: [String: Any]?
                if oid == 0 || method.isEmpty {
                    throw SPLKError.inner
                } else if let inspectingApp = SPLKAppsManager.sharedInstance.inspectingApp {
                    value = try await inspectingApp.invokeMethod(withOid: oid, text: method)
                } else {
                    throw SPLKError.noConnect
                }

                guard let window = self?.view.window else { return }
                let alert = NSAlert()
                alert.messageText = method
                alert.informativeText = value?["description"] as? String ?? ""
                alert.alertStyle = .informational
                alert.beginSheetModal(for: window) { _ in
                }

            } catch {
                SPLKHelper.alertError(error, window: self?.view.window)
            }
        }
    }

    // MARK: - SPLKDashboardSearchPropViewDelegate

    func dashboardSearchPropView(_ view: SPLKDashboardSearchPropView, didClickRevealAttribute clickedAttr: SPLKAttribute?) {
        headerView.isActive = false

        var targetGroup: SPLKAttributesGroup?
        var targetSection: SPLKAttributesSection?

        search: for group in currentDataSource()?.selectedItem?.queryAllAttrGroupList() ?? [] {
            for section in group.attrSections ?? [] {
                for attr in section.attributes ?? [] where attr === clickedAttr {
                    let isAlreadyAdded = SPLKPreferenceManager.mainManager.isSectionShowing(section.identifier)
                    if !isAlreadyAdded {
                        // 把这个属性添加到主面板上
                        SPLKPreferenceManager.mainManager.showSection(section.identifier)
                    }

                    targetGroup = group
                    targetSection = section
                    break search
                }
            }
        }

        guard let targetGroup, let targetSection else {
            assertionFailure()
            return
        }
        guard let targetCardView = cardViews[targetGroup.uniqueKey()] else {
            assertionFailure()
            return
        }
        if targetCardView.isCollapsed {
            // 如果在折叠状态则展开
            dashboardCardViewNeedToggleCollapse(targetCardView)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let targetSecView = targetCardView.querySectionView(with: targetSection) else { return }
            self.scrollView.contentView.animator().scrollToVisible(self.scrollView.contentView.convert(targetSecView.frame, from: targetSecView.superview))

            for cardView in self.cardViews.values {
                if cardView.isHidden {
                    continue
                }
                if cardView === targetCardView {
                    cardView.playFadeAnimation(withHighlightRect: cardView.convert(targetSecView.frame, from: targetSecView.superview))
                } else {
                    cardView.playFadeAnimation(withHighlightRect: .zero)
                }
            }
        }
    }
}
