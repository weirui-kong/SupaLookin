//
//  LKHierarchyDataSource.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/6.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import LookinShared

enum LKHierarchyDataSourceState {
    case normal
    case search
    case focus
}

private final class LKSelectColorItem {

    var title: String?
    var color: NSColor?

    init(title: String?, color: NSColor?) {
        self.title = title
        self.color = color
    }
}

private final class LKSelectColorItemsSection {

    var title: String?

    private(set) var items: [LKSelectColorItem] = []

    func setItems(_ items: [LKSelectColorItem]) {
        self.items = items.sorted { ($0.title ?? "").caseInsensitiveCompare($1.title ?? "") == .orderedAscending }
    }
}

private enum LKSelectColorMenuEntry {
    case item(LKSelectColorItem)
    case section(LKSelectColorItemsSection)
}

private extension LookinDisplayItem {

    /// 记录搜索之前的 isExpanded 的值，用来在结束搜索后恢复
    var isExpandedBeforeSearchOrFocus: Bool {
        get { lookin_getBindBOOL(forKey: "isExpandedBeforeSearching") }
        set { lookin_bindBOOL(newValue, forKey: "isExpandedBeforeSearching") }
    }
}

class LKHierarchyDataSource {

    /// 业务可以 observe 该属性
    private(set) var state: LKHierarchyDataSourceState = .normal {
        didSet {
            stateObservation.notify()
        }
    }

    let willReloadHierarchyInfo = PassthroughSubject<Void, Never>()
    let didReloadHierarchyInfo = PassthroughSubject<Void, Never>()

    var rawFlatItems: [LookinDisplayItem] = [] {
        didSet {
            var map: [UInt: LookinDisplayItem] = [:]
            map.reserveCapacity(rawFlatItems.count * 2)
            for obj in rawFlatItems {
                if let oid = obj.viewObject?.oid, oid != 0 {
                    map[oid] = obj
                }
                if let oid = obj.layerObject?.oid, oid != 0 {
                    map[oid] = obj
                }
            }
            oidToDisplayItemMap = map
        }
    }

    /// 一维数组，包含所有 hierarchy 树中可见和不可见的 displayItems
    /// 搜索或聚焦状态下，flatItems 是 rawFlatItems 的子集（normal 状态下，flatItems 和 rawFlatItems 等价）
    var flatItems: [LookinDisplayItem] = []

    /// 一维数组，只包括在 hierarchy 树中因为未被折叠而可见的 displayItems。它是 flatItems 的子集，当用户展开或收起 item 时会被 buildDisplayingFlatItems 不断更新
    /// 业务可以 observe 该属性
    private(set) var displayingFlatItems: [LookinDisplayItem] = [] {
        didSet {
            displayingFlatItemsObservation.notify()
        }
    }

    private weak var storedSelectedItem: LookinDisplayItem?
    private weak var storedHoveredItem: LookinDisplayItem?

    /// 当前选中的 item
    var selectedItem: LookinDisplayItem? {
        get {
            storedSelectedItem
        }
        set {
            defer { selectedItemObservation.notify() }
            if storedSelectedItem === newValue {
                return
            }
            let prevItem = storedSelectedItem
            storedSelectedItem = newValue

            prevItem?.notifySelectionChangeToDelegates()
            newValue?.notifySelectionChangeToDelegates()
            LKUserActionManager.sharedInstance.sendAction(.selectedItemChange)

            if NSColorPanel.sharedColorPanelExists {
                NSColorPanel.shared.close()
            }
            if newValue == nil && preferenceManager.measureState.currentIntegerValue != LookinMeasureState.no.rawValue {
                // 如果当前在测距，则取消
                preferenceManager.measureState.setIntegerValue(LookinMeasureState.no.rawValue, ignoreSubscriber: nil)
            }
        }
    }

    /// 当前被鼠标 hover 的 item
    var hoveredItem: LookinDisplayItem? {
        get {
            storedHoveredItem
        }
        set {
            defer { hoveredItemObservation.notify() }
            if storedHoveredItem === newValue {
                return
            }
            let prevItem = storedHoveredItem
            storedHoveredItem = newValue
            prevItem?.notifyHoverChangeToDelegates()
            newValue?.notifyHoverChangeToDelegates()
        }
    }

    private(set) var rawHierarchyInfo: LookinHierarchyInfo? {
        didSet {
            rawHierarchyInfoObservation.notify()
        }
    }

    /// 某个 item 的 isHidden 或 alpha 发生改变
    let itemDidChangeHiddenAlphaValue = PassthroughSubject<LookinDisplayItem, Never>()
    /// 某个 item 的 attrGroup 改变
    let itemDidChangeAttrGroup = PassthroughSubject<LookinDisplayItem, Never>()
    let itemDidChangeNoPreview = PassthroughSubject<Void, Never>()

    /// 由于搜索或 Focus 而修改了 flatItems
    let didReloadFlatItemsWithSearchOrFocus = PassthroughSubject<Void, Never>()

    /// 在 dashboard 里选择颜色时弹出的 menu
    private(set) var selectColorMenu: NSMenu?

    /// 该 tag 标示这个 menuItem 是“自定义……”那个选项
    let customColorMenuItemTag = 10
    /// The menu tag of "switch color format"
    let toggleColorFormatMenuItemTag = 11

    /// 当该属性为 true 时，表示正处于 dashboard 搜索状态中，此时 preview 界面不应该响应图层点击
    var shouldAvoidChangingPreviewSelectionDueToDashboardSearch = false

    private(set) var serverSideIsSwiftProject = false

    private var oidToDisplayItemMap: [UInt: LookinDisplayItem] = [:]

    /**
     key 是 rgba 字符串，value 是 alias 字符串数组，比如：

     [
     "(255, 255, 255, 1)": ["MyWhite", "MainThemeWhite"],
     "(255, 0, 0, 0.5)": ["BestRed", "TransparentRed"]
     ]
     */
    private var colorToAliasMap: [String: [String]] = [:]

    private lazy var stateObservation = LKKVOSubject { [unowned self] in self.state }
    private lazy var displayingFlatItemsObservation = LKKVOSubject { [unowned self] in self.displayingFlatItems }
    private lazy var selectedItemObservation = LKKVOSubject { [unowned self] in self.selectedItem }
    private lazy var hoveredItemObservation = LKKVOSubject { [unowned self] in self.hoveredItem }
    private lazy var rawHierarchyInfoObservation = LKKVOSubject { [unowned self] in self.rawHierarchyInfo }

    var statePublisher: AnyPublisher<LKHierarchyDataSourceState, Never> { stateObservation.publisher }
    var displayingFlatItemsPublisher: AnyPublisher<[LookinDisplayItem], Never> { displayingFlatItemsObservation.publisher }
    var selectedItemPublisher: AnyPublisher<LookinDisplayItem?, Never> { selectedItemObservation.publisher }
    var hoveredItemPublisher: AnyPublisher<LookinDisplayItem?, Never> { hoveredItemObservation.publisher }
    var rawHierarchyInfoPublisher: AnyPublisher<LookinHierarchyInfo?, Never> { rawHierarchyInfoObservation.publisher }

    private var cancellables = Set<AnyCancellable>()

    init() {
        LKPreferenceManager.mainManager.rgbaFormatPublisher
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.setUpColors()
            }
            .store(in: &cancellables)
    }

    deinit {
        NSLog("%@ dealloc", String(describing: type(of: self)))
    }

    /**
     如果 keepState 为 true，则会尽量维持刷新之前的折叠状态和选中态
     */
    func reload(with info: LookinHierarchyInfo, keepState: Bool) {
        rawHierarchyInfo = info

        willReloadHierarchyInfo.send(())
        if (info.colorAlias?.count ?? 0) > 0 {
            LKPreferenceManager.mainManager.receivingConfigTime_Color = Date().timeIntervalSince1970
        }
        if (info.collapsedClassList?.count ?? 0) > 0 {
            LKPreferenceManager.mainManager.receivingConfigTime_Class = Date().timeIntervalSince1970
        }

        var prevSelectedOid: UInt = 0
        var prevExpansionMap: [UInt: Bool]?
        if keepState {
            prevSelectedOid = selectedItem?.layerObject?.oid ?? 0

            var map: [UInt: Bool] = [:]
            for obj in flatItems {
                map[obj.layerObject?.oid ?? 0] = obj.isExpanded
            }
            prevExpansionMap = map
        }

        // 设置 color alias 和 select color menu
        setUpColors()

        // 根据 subitems 属性打平为二维数组，同时给每个 item 设置 indentLevel
        rawFlatItems = LookinDisplayItem.flatItems(fromHierarchicalItems: info.displayItems ?? [])
        let flatItems = rawFlatItems

        // 设置 preferToBeCollapsed 属性
        var classesPreferredToCollapse: Set<String> = ["UILabel", "UIPickerView", "UIProgressView", "UIActivityIndicatorView", "UIAlertView", "UIActionSheet", "UISearchBar", "UIButton", "UITextView", "UIDatePicker", "UIPageControl", "UISegmentedControl", "UITextField", "UISlider", "UISwitch", "UIVisualEffectView", "UIImageView", "WKCommonWebView", "UITextEffectsWindow"]
        if let collapsedClassList = info.collapsedClassList, !collapsedClassList.isEmpty {
            classesPreferredToCollapse.formUnion(collapsedClassList)
        }
        // no preview
        let classesWithNoPreview: Set<String> = ["UITextEffectsWindow", "UIRemoteKeyboardWindow"]

        for obj in flatItems {
            if obj.itemIsKindOfClasses(withNames: classesPreferredToCollapse) {
                obj.enumerateSelfAndChildren { $0.preferToBeCollapsed = true }
            }

            if obj.indentLevel() == 0 {
                if obj.itemIsKindOfClasses(withNames: classesWithNoPreview) {
                    obj.noPreview = true
                }
            }

            if !obj.isUserCustom && !obj.shouldCaptureImage {
                obj.enumerateSelfAndChildren { item in
                    item.noPreview = true
                    item.doNotFetchScreenshotReason = .doNotFetchScreenshotForUserConfig
                }
            }

            if !serverSideIsSwiftProject {
                if obj.displayingObject()?.completedDemangledClassName.contains(".") == true {
                    serverSideIsSwiftProject = true
                }
            }

            if let danceuiSource = obj.customInfo?.danceuiSource, !danceuiSource.isEmpty {
                LKDanceUIAttrMaker.makeDanceUIJumpAttribute(obj, danceSource: danceuiSource)
            }
        }

        self.flatItems = flatItems

        // 设置选中
        var shouldSelectedItem: LookinDisplayItem?
        if keepState, let prevSelectedItem = displayItem(withOid: prevSelectedOid) {
            shouldSelectedItem = prevSelectedItem
        }
        // 设置展开和折叠
        var expansionIndex = preferenceManager.expansionIndex
        if self.flatItems.count > 300 {
            if expansionIndex > 2 {
                expansionIndex = 2
            }
        }
        if shouldSelectedItem != nil {
            adjustExpansion(byIndex: expansionIndex, referenceDict: keepState ? prevExpansionMap : nil)
        } else {
            shouldSelectedItem = adjustExpansion(byIndex: expansionIndex, referenceDict: keepState ? prevExpansionMap : nil, wantsSelectedItem: true)
        }

        if self.flatItems.count > 20 && displayingFlatItems.count < 10 && expansionIndex > 1 {
            // 被展开的图层太少了，所以忽略 referDict 重新调整。通常是由于 iOS App 重新编译或者界面改变了导致之前被展开的图层都被释放掉了
            NSLog("adjust expansion again")
            adjustExpansion(byIndex: expansionIndex, referenceDict: nil)
        }

        if shouldSelectedItem == nil {
            shouldSelectedItem = self.flatItems.first
        }
        selectedItem = shouldSelectedItem
        if state != .normal {
            // 可能在 search 或 focus 状态，要退出
            state = .normal
        }

        didReloadHierarchyInfo.send(())
    }

    /// 当前应该被显示的 rows 行数
    func numberOfRows() -> Int {
        displayingFlatItems.count
    }

    /// 获取指定行的 item
    func item(atRow index: Int) -> LookinDisplayItem? {
        if index < 0 {
            return nil
        }
        return displayingFlatItems.element(at: index)
    }

    /// 获取指定 item 的 row，可能为 NSNotFound
    func row(for item: LookinDisplayItem?) -> Int {
        guard let item else {
            return NSNotFound
        }
        return displayingFlatItems.firstIndex { $0 === item } ?? NSNotFound
    }

    /**
     index 范围：0 ~ 4
     referenceDict 的 key 为 layerOid，value 为 true/false 即是否展开，它记录了一组 displayItem 的展开状态
     在调整一个 item 的 expansion 时，如果 referenceDict 中存在这个 item 的记录则会采用 referenceDict 里的数据，否则会重新根据 index 来调整
     wantsSelectedItem 为 true 时返回这次调整所建议选中的 item
     */
    @discardableResult
    func adjustExpansion(byIndex index: Int, referenceDict: [UInt: Bool]?, wantsSelectedItem: Bool = false) -> LookinDisplayItem? {
        var index = index
        if index < 0 || index > 4 {
            assertionFailure("adjustExpansionByIndex, index 为 \(index)")
            index = max(min(index, 4), 0)
        }

        preferenceManager.expansionIndex = index

        var suggestedSelectedItem: LookinDisplayItem?

        for obj in flatItems {
            obj.hasDeterminedExpansion = false
            if !obj.isExpandable {
                obj.hasDeterminedExpansion = true
                continue
            }

            if let referenceDict, let prevState = referenceDict[obj.layerObject?.oid ?? 0] {
                // 旧的对象，直接维持之前的状态
                obj.isExpanded = prevState
                obj.hasDeterminedExpansion = true
            }
        }

        if index == 0 {
            // 全部折叠，只剩下最顶层的 UIWindow
            var preferedSelectedItem: LookinDisplayItem?
            for obj in flatItems where !obj.hasDeterminedExpansion {
                obj.isExpanded = false
                if obj.representedAsKeyWindow {
                    preferedSelectedItem = obj
                }
            }
            if wantsSelectedItem {
                suggestedSelectedItem = preferedSelectedItem
            }

        } else if index == 4 {
            // 全部展开，包括 UIButton、UITabBar、UINavigationBar 等等，全部展开
            for obj in flatItems where !obj.hasDeterminedExpansion {
                if obj.inNoPreviewHierarchy {
                    obj.isExpanded = false
                    continue
                }
                obj.isExpanded = true
            }

            if wantsSelectedItem {
                var preferedSelectedItem: LookinDisplayItem?
                if let keyWindowRootItem = rawHierarchyInfo?.displayItems?.first(where: { $0.representedAsKeyWindow }) {
                    let items = LookinDisplayItem.flatItems(fromHierarchicalItems: [keyWindowRootItem]) ?? []
                    preferedSelectedItem = items.last { $0.hostViewControllerObject != nil }
                }
                suggestedSelectedItem = preferedSelectedItem
            }

        } else {
            let displayItems = rawHierarchyInfo?.displayItems ?? []
            let keyWindowItem = displayItems.first { $0.representedAsKeyWindow } ?? displayItems.first
            for windowItem in displayItems where windowItem !== keyWindowItem {
                // 非 keyWindow 上的都折叠起来
                for obj in LookinDisplayItem.flatItems(fromHierarchicalItems: [windowItem]) where !obj.hasDeterminedExpansion {
                    obj.isExpanded = false
                    obj.hasDeterminedExpansion = true
                }
            }

            let transitionViewItems = (keyWindowItem?.subitems ?? []).filter { $0.title == "UITransitionView" }
            for (idx, obj) in transitionViewItems.enumerated() where !obj.hasDeterminedExpansion {
                // 展开最后一个 UITransitionView，折叠前几个 UITransitionView
                obj.isExpanded = (idx == transitionViewItems.count - 1)
                obj.hasDeterminedExpansion = true
            }

            var viewControllerItems: [LookinDisplayItem] = []
            let keyWindowFlatItems = keyWindowItem.flatMap { LookinDisplayItem.flatItems(fromHierarchicalItems: [$0]) } ?? []
            for obj in keyWindowFlatItems {
                if obj.hostViewControllerObject != nil {
                    viewControllerItems.append(obj)
                    continue
                }
                if obj.hasDeterminedExpansion {
                    continue
                }
                // The Objective-C code also tested `!showHiddenItems && obj.inHiddenHierarchy`, but showHiddenItems is an
                // attribute object, so `!showHiddenItems` was always false and that clause never applied.
                if obj.inNoPreviewHierarchy || obj.preferToBeCollapsed {
                    // 把 noPreview 和 UIButton 之类常用控件叠起来
                    obj.isExpanded = false
                    obj.hasDeterminedExpansion = true
                    continue
                }
                if obj.itemIsKindOfClasses(withNames: ["UINavigationBar", "UITabBar"]) {
                    // 把 NavigationBar 和 TabBar 折叠起来
                    obj.enumerateSelfAndChildren { item in
                        if item.hasDeterminedExpansion {
                            return
                        }
                        item.isExpanded = false
                        item.hasDeterminedExpansion = true
                    }
                    continue
                }
            }

            if wantsSelectedItem {
                suggestedSelectedItem = viewControllerItems.last
            }

            if index == 1 {
                // 恰好把 viewController 显示出来
                // 倒序，以确保多个 viewController 在同一条树上时，只有最 leaf 的那一个是被折叠的
                for viewControllerItem in viewControllerItems.reversed() {
                    viewControllerItem.enumerateSelfAndAncestors { item in
                        // 把 viewController 的 ancestors 都展开
                        if item.hasDeterminedExpansion {
                            return false
                        }
                        item.isExpanded = (item !== viewControllerItem)
                        item.hasDeterminedExpansion = true
                        return false
                    }
                }

                // 剩下未处理的都折叠
                for obj in flatItems where !obj.hasDeterminedExpansion {
                    obj.isExpanded = false
                }

            } else if index == 2 {
                // 从 viewController 开始算向 leaf 多推 3 层
                for viewControllerItem in viewControllerItems.reversed() {
                    viewControllerItem.enumerateAncestors { item in
                        // 把 viewController 的 ancestors 都展开
                        if item.hasDeterminedExpansion {
                            return false
                        }
                        item.isExpanded = true
                        item.hasDeterminedExpansion = true
                        return false
                    }

                    let hasTableOrCollectionView = viewControllerItem.subitems?.first?.itemIsKindOfClasses(withNames: ["UITableView", "UICollectionView"]) ?? false
                    // 如果是那种典型的 UITableView 或 UICollectionView 的话，则向 leaf 方向推进 2 层（这样就可以让 cell 恰好露出来而不露出来 cell 的 contentView），否则就推 3 层
                    let indentsForward = hasTableOrCollectionView ? 2 : 3
                    viewControllerItem.enumerateSelfAndChildren { item in
                        if item.hasDeterminedExpansion {
                            return
                        }
                        if item.indentLevel() < viewControllerItem.indentLevel() + indentsForward {
                            item.isExpanded = true
                            item.hasDeterminedExpansion = true
                        }
                    }
                }

                // 剩下未处理的都折叠
                for obj in flatItems where !obj.hasDeterminedExpansion {
                    obj.isExpanded = false
                }

            } else if index == 3 {
                // 展开大部分
                for obj in flatItems where !obj.hasDeterminedExpansion {
                    obj.isExpanded = true
                    obj.hasDeterminedExpansion = true
                }
            }
        }

        buildDisplayingFlatItems()
        return suggestedSelectedItem
    }

    /// 通过 oid 找到对应的 displayItem
    func displayItem(withOid oid: UInt) -> LookinDisplayItem? {
        oidToDisplayItemMap[oid]
    }

    func buildDisplayingFlatItems() {
        displayingFlatItems = flatItems.filter { $0.displayingInHierarchy }
    }

    /// 将 item 折叠起来，如果该 item 没有 subitems 或已经被折叠，则该方法不起任何作用
    func collapseItem(_ item: LookinDisplayItem) {
        if !item.isExpandable || !item.isExpanded {
            return
        }
        item.isExpanded = false
        buildDisplayingFlatItems()
    }

    /// 将 item 展开，如果该 item 没有 subitems 或已经被展开，则该方法不起任何作用
    func expandItem(_ item: LookinDisplayItem) {
        if !item.isExpandable || item.isExpanded {
            return
        }
        item.isExpanded = true
        buildDisplayingFlatItems()
    }

    /// 如果 item 在 hierarchy 中可见则该方法不执行任何操作，否则会将 item 的所有上级元素展开以显示 item
    func expandToShowItem(_ item: LookinDisplayItem) {
        item.enumerateAncestors { targetItem in
            if !targetItem.isExpanded {
                targetItem.isExpanded = true
            }
            return false
        }
        buildDisplayingFlatItems()
    }

    /// 把 item 及所有后代元素全部展开
    func expandItemsRooted(by item: LookinDisplayItem) {
        if item.preferToBeCollapsed {
            item.enumerateSelfAndChildren { targetItem in
                if targetItem.isExpandable && !targetItem.isExpanded {
                    targetItem.isExpanded = true
                }
            }
        } else {
            item.enumerateSelfAndChildren { targetItem in
                if targetItem.isExpandable && !targetItem.isExpanded && !targetItem.preferToBeCollapsed {
                    targetItem.isExpanded = true
                }
            }
        }
        buildDisplayingFlatItems()
    }

    /// 把 item 所有后代元素全部折叠（但是不折叠 item 自身）
    func collapseAllChildren(of item: LookinDisplayItem) {
        item.enumerateSelfAndChildren { enumeratedItem in
            if enumeratedItem === item || !enumeratedItem.isExpandable || !enumeratedItem.isExpanded {
                return
            }
            enumeratedItem.isExpanded = false
        }
        buildDisplayingFlatItems()
    }

    // MARK: - Search

    /// 应该在用户输入搜索词时调用该方法，内部会直接更改 flatItems 和 displayingFlatItems 对象
    /// string 不能为空字符串
    func search(with string: String) {
        guard !string.isEmpty else {
            assertionFailure()
            return
        }

        if state != .search {
            rawFlatItems.forEach { $0.isExpandedBeforeSearchOrFocus = $0.isExpanded }
            state = .search
        }

        selectedItem = nil

        // 被打上这个标记的都是本次搜索需要在界面中显示出来的（尽管可能会被折叠）
        let Key_ShouldShow = "show"
        for displayItem in rawFlatItems {
            displayItem.lookin_bindBOOL(false, forKey: Key_ShouldShow)
            displayItem.highlightedSearchString = nil
        }
        for displayItem in rawFlatItems where displayItem.isMatched(withSearchString: string) {
            displayItem.highlightedSearchString = string
            displayItem.enumerateAncestors { ancestor in
                // 上级元素都显示且展开
                ancestor.isExpanded = true
                ancestor.lookin_bindBOOL(true, forKey: Key_ShouldShow)
                return false
            }
            displayItem.enumerateSelfAndChildren { selfOrChild in
                // 自身和下级元素都显示但折叠，允许用户手动展开
                selfOrChild.isExpanded = false
                selfOrChild.lookin_bindBOOL(true, forKey: Key_ShouldShow)
            }
        }

        flatItems = rawFlatItems.filter { displayItem in
            let shouldShow = displayItem.lookin_getBindBOOL(forKey: Key_ShouldShow)
            if shouldShow {
                displayItem.isInSearch = true
            }
            return shouldShow
        }
        didReloadFlatItemsWithSearchOrFocus.send(())

        buildDisplayingFlatItems()
    }

    // 有可能从 normal 状态或 search 状态进入该状态
    func focusDisplayItem(_ item: LookinDisplayItem) {
        if state == .normal {
            rawFlatItems.forEach { $0.isExpandedBeforeSearchOrFocus = $0.isExpanded }
        } else if state == .search {
            rawFlatItems.forEach { obj in
                obj.isInSearch = false
                obj.highlightedSearchString = nil
            }
        }
        state = .focus
        var newFlatItems: [LookinDisplayItem] = []
        item.enumerateSelfAndChildren { newFlatItems.append($0) }
        flatItems = newFlatItems
        didReloadFlatItemsWithSearchOrFocus.send(())
        buildDisplayingFlatItems()
    }

    func endFocus() {
        if state == .normal {
            return
        }
        state = .normal

        rawFlatItems.forEach { $0.isExpanded = $0.isExpandedBeforeSearchOrFocus }

        flatItems = rawFlatItems
        didReloadFlatItemsWithSearchOrFocus.send(())
        buildDisplayingFlatItems()
    }

    /// 应该在点击搜索框的关闭按钮时调用该方法，用来恢复搜索前的状态等一系列工作
    func endSearch() {
        if state == .normal {
            return
        }
        state = .normal

        for obj in rawFlatItems {
            obj.isInSearch = false
            obj.highlightedSearchString = nil
            obj.isExpanded = obj.isExpandedBeforeSearchOrFocus
        }
        // 搜索时被选中的 item，在结束搜索后也应该处于被选中且可见的状态
        selectedItem?.enumerateAncestors { item in
            item.isExpanded = true
            return false
        }

        flatItems = rawFlatItems
        didReloadFlatItemsWithSearchOrFocus.send(())

        buildDisplayingFlatItems()
    }

    // MARK: - Colors

    /// 某个颜色的业务别名，如果不存在则返回 nil
    func alias(for color: NSColor?) -> [String]? {
        guard let color else {
            return nil
        }
        return colorToAliasMap[color.rgbaString]
    }

    private func setUpColors() {
        var colorToAliasMap: [String: [String]] = [:]
        // 成员可能是 item 和 section 混杂在一起
        var aliasColorItemsOrSections: [LKSelectColorMenuEntry] = []

        /**
         hierarchyInfo.colorAlias 可以有三种结构：
         1）key 是颜色别名，value 是 UIColor/NSColor。即 <NSString *, Color *>
         2）key 是一组颜色的标题，value 是 NSDictionary，而这个 NSDictionary 的 key 是颜色别名，value 是 UIColor / NSColor。即 <NSString *, NSDictionary<NSString *, Color *> *>
         3）以上两者混在一起
         */
        (rawHierarchyInfo?.colorAlias as NSDictionary?)?.enumerateKeysAndObjects { key, colorOrDict, _ in
            guard let key = key as? String else {
                return
            }
            if let color = colorOrDict as? NSColor {
                colorToAliasMap[color.rgbaString, default: []].append(key)
                aliasColorItemsOrSections.append(.item(LKSelectColorItem(title: key, color: color)))

            } else if let dict = colorOrDict as? NSDictionary {
                let section = LKSelectColorItemsSection()
                section.title = key
                var aliasItems: [LKSelectColorItem] = []

                dict.enumerateKeysAndObjects { colorAliaName, colorObj, _ in
                    guard let colorAliaName = colorAliaName as? String else {
                        return
                    }
                    let colorObj = colorObj as? NSColor
                    if let colorDesc = colorObj?.rgbaString {
                        colorToAliasMap[colorDesc, default: []].append(colorAliaName)
                    }
                    aliasItems.append(LKSelectColorItem(title: colorAliaName, color: colorObj))
                }

                if !aliasItems.isEmpty {
                    section.setItems(aliasItems)
                    aliasColorItemsOrSections.append(.section(section))
                }

            } else {
                assertionFailure()
            }
        }

        aliasColorItemsOrSections.sort { lhs, rhs in
            switch (lhs, rhs) {
            case let (.item(obj1), .item(obj2)):
                return (obj1.title ?? "").caseInsensitiveCompare(obj2.title ?? "") == .orderedAscending
            case (.item, .section):
                return true
            case (.section, .item):
                return false
            case let (.section(obj1), .section(obj2)):
                return (obj1.title ?? "").caseInsensitiveCompare(obj2.title ?? "") == .orderedAscending
            }
        }

        self.colorToAliasMap = colorToAliasMap
        selectColorMenu = makeMenu(withAliasColorItemsOrSections: aliasColorItemsOrSections, usingRGBAFormat: LKPreferenceManager.mainManager.rgbaFormat)
    }

    private func makeMenu(withAliasColorItemsOrSections aliasColorItemsOrSections: [LKSelectColorMenuEntry], usingRGBAFormat rgbaFormat: Bool) -> NSMenu {
        var menuModel: [LKSelectColorMenuEntry] = []

        menuModel.append(.item(LKSelectColorItem(title: "nil", color: nil)))
        menuModel.append(.item(LKSelectColorItem(title: "clear color", color: NSColor(lookinRed: 0, green: 0, blue: 0, alpha: 0))))

        let defaultColors: [NSColor] = [NSColor(lookinRed: 0, green: 0, blue: 0),
                                        NSColor(lookinRed: 126, green: 126, blue: 126),
                                        NSColor(lookinRed: 255, green: 255, blue: 255),
                                        NSColor(lookinRed: 0, green: 166, blue: 248, alpha: 0.5),
                                        NSColor(lookinRed: 253, green: 62, blue: 0),
                                        NSColor(lookinRed: 105, green: 190, blue: 0),
                                        NSColor(lookinRed: 254, green: 182, blue: 2)]
        for color in defaultColors {
            menuModel.append(.item(LKSelectColorItem(title: rgbaFormat ? color.rgbaString : color.hexString, color: color)))
        }

        let defaultItemsCount = menuModel.count

        menuModel.append(contentsOf: aliasColorItemsOrSections)

        let menu = NSMenu()
        for (idx, entry) in menuModel.enumerated() {
            if idx == defaultItemsCount {
                menu.addItem(.separator())
            }

            switch entry {
            case .section(let itemsSection):
                let sectionItem = NSMenuItem()
                sectionItem.image = NSImage(size: NSSize(width: 1, height: 22))
                menu.addItem(sectionItem)
                sectionItem.title = itemsSection.title ?? ""

                let submenu = NSMenu()
                itemsSection.items.forEach { submenu.addItem(menuItem(from: $0)) }
                sectionItem.submenu = submenu

            case .item(let item):
                menu.addItem(menuItem(from: item))
            }
        }

        menu.addItem(.separator())
        let customItem = NSMenuItem()
        customItem.image = NSImage(size: NSSize(width: 1, height: 22))
        customItem.title = NSLocalizedString("Other…", comment: "")
        customItem.tag = customColorMenuItemTag
        menu.addItem(customItem)

        menu.addItem(.separator())
        let toggleItem = NSMenuItem()
        toggleItem.image = NSImage(size: NSSize(width: 1, height: 22))
        toggleItem.title = rgbaFormat ? NSLocalizedString("Switch color format to HEX", comment: "") : NSLocalizedString("Switch color format to RGBA", comment: "")
        toggleItem.tag = toggleColorFormatMenuItemTag
        menu.addItem(toggleItem)

        return menu
    }

    private func menuItem(from item: LKSelectColorItem) -> NSMenuItem {
        let image = LKColorIndicatorLayer.image(with: item.color, shapeSize: NSSize(width: 20, height: 20), insets: NSEdgeInsets(top: 4, left: 5, bottom: 4, right: 6))
        let menuItem = NSMenuItem()
        menuItem.image = image
        menuItem.title = item.title ?? ""
        menuItem.representedObject = item.color
        return menuItem
    }

    // MARK: - Others

    /// 子类实现该方法
    var preferenceManager: LKPreferenceManager {
        fatalError("should implement by subclass")
    }

    /// 只读模式下（比如打开一个文件），该方法返回 true
    var isReadOnly: Bool {
        true
    }
}
