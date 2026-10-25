//
//  LKHierarchyView.swift
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

private let kMenuBindKey_RowView = "view"
private let kRowHeight: CGFloat = 28

protocol LKHierarchyViewDelegate: AnyObject {
    func hierarchyView(_ view: LKHierarchyView, didSelectItem item: LookinDisplayItem)
    func hierarchyView(_ view: LKHierarchyView, didDoubleClickItem item: LookinDisplayItem)
    func hierarchyView(_ view: LKHierarchyView, didHoverAtItem item: LookinDisplayItem?)
    func hierarchyView(_ view: LKHierarchyView, needToExpandItem item: LookinDisplayItem, recursively: Bool)
    func hierarchyView(_ view: LKHierarchyView, needToCollapseItem item: LookinDisplayItem)
    func hierarchyView(_ view: LKHierarchyView, needToCollapseChildrenOfItem item: LookinDisplayItem)
    /// 在底部的搜索框里输入了文字，string 可能为空字符串或 nil
    /// 当用户通过搜索框的关闭按钮、ESC 等方式手动结束搜索时，该方法同样会被调用，参数是 nil
    func hierarchyView(_ view: LKHierarchyView, didInputSearchString string: String?)
    func hierarchyView(_ view: LKHierarchyView, needToCancelPreviewOfItem item: LookinDisplayItem)
    func hierarchyView(_ view: LKHierarchyView, needToShowPreviewOfItem item: LookinDisplayItem)
}

final class LKHierarchyView: LKBaseView, LKTableViewDelegate, LKTableViewDataSource, NSMenuDelegate, NSTextFieldDelegate {

    let tableView = LKTableView()
    var dataSource: LKHierarchyDataSource
    weak var delegate: LKHierarchyViewDelegate?

    private let backgroundEffectView = LKVisualEffectView()
    private let guidesShapeLayer = CAShapeLayer()
    private let searchTextFieldView = LKTextFieldView()
    private var emptyDataLabel: LKLabel?
    private var displayItems: [LookinDisplayItem] = []
    private var minIndentLevel = 0
    private var cancellables = Set<AnyCancellable>()

    init(dataSource: LKHierarchyDataSource) {
        self.dataSource = dataSource
        super.init(frame: .zero)

        backgroundEffectView.material = .sidebar
        backgroundEffectView.blendingMode = .behindWindow
        backgroundEffectView.state = .active
        addSubview(backgroundEffectView)

        tableView.adjustsSelectionAutomatically = false
        tableView.delegate = self
        tableView.dataSource = self
        addSubview(tableView)
        tableView.reloadData()

        guidesShapeLayer.lineWidth = 1
        guidesShapeLayer.isHidden = true
        guidesShapeLayer.lookin_removeImplicitAnimations()
        guidesShapeLayer.lineDashPattern = [2, 2]
        tableView.contentView.documentView?.layer?.addSublayer(guidesShapeLayer)

        searchTextFieldView.textField.placeholderString = NSLocalizedString("Filter", comment: "")
        searchTextFieldView.initCloseButton()
        searchTextFieldView.insets = NSEdgeInsets(top: 0, left: 7, bottom: 0, right: 1)
        searchTextFieldView.textField.font = .systemFont(ofSize: 13)
        searchTextFieldView.textField.usesSingleLineMode = true
        searchTextFieldView.textField.lineBreakMode = .byTruncatingTail
        searchTextFieldView.textField.drawsBackground = false
        searchTextFieldView.textField.isBordered = false
        searchTextFieldView.textField.focusRingType = .none
        searchTextFieldView.borderPosition = .top
        searchTextFieldView.borderColors = LKTwoColors(lightMode: NSColor(lookinRed: 200, green: 201, blue: 202), darkMode: NSColor(lookinRed: 67, green: 68, blue: 69))
        searchTextFieldView.image = NSImage(named: "icon_hierarchy_search")
        searchTextFieldView.textField.delegate = self
        addSubview(searchTextFieldView)

        let textField = searchTextFieldView.textField
        // rac_textSignal starts with the current text; RAC's throttle forwards the latest value once typing pauses, then skip:1 drops the first.
        NotificationCenter.default.publisher(for: NSControl.textDidChangeNotification, object: textField)
            .map { _ in textField.stringValue }
            .prepend(textField.stringValue)
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .dropFirst()
            .sink { [weak self] x in
                guard let self else { return }
                // 去掉所有空白字符
                let string = x.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
                self.delegate?.hierarchyView(self, didInputSearchString: string)
            }
            .store(in: &cancellables)
        searchTextFieldView.closeButton?.onAction { [weak self] _ in
            self?.exitAndClearSearch()
        }

        var previousInsets: NSEdgeInsets?
        tableView.publisher(for: \.contentInsets)
            .filter { insets in
                defer { previousInsets = insets }
                guard let previousInsets else { return true }
                return !NSEdgeInsetsEqual(previousInsets, insets)
            }
            .sink { insets in
                LKNavigationManager.sharedInstance.windowTitleBarHeight = insets.top
            }
            .store(in: &cancellables)

        dataSource.selectedItemPublisher
            .sink { [weak self] item in
                guard let self else { return }
                self.tableView.reloadDataWithOffset()
                self.scrollToMakeItemVisible(item)
            }
            .store(in: &cancellables)

        dataSource.hoveredItemPublisher
            .removeDuplicates { $0 === $1 }
            .sink { [weak self] item in
                self?.updateGuides(withHoveredItem: item)
            }
            .store(in: &cancellables)

        dataSource.displayingFlatItemsPublisher
            .sink { [weak self] items in
                guard let self else { return }
                self.render(withDisplayItems: items)
                DispatchQueue.main.async {
                    self.updateGuides(withHoveredItem: self.dataSource.hoveredItem)
                }
            }
            .store(in: &cancellables)
        dataSource.displayingFlatItemsPublisher
            .debounce(for: .seconds(0.75), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.bringGuidesLayerToFront()
            }
            .store(in: &cancellables)
        dataSource.statePublisher
            .sink { [weak self] state in
                guard let self else { return }
                // 隐藏搜索功能，避免同时处于 focus 和 search 状态，从而避免状态维护太过复杂
                let isFocus = state == .focus
                self.searchTextFieldView.isHidden = isFocus

                if isFocus && !self.searchTextFieldView.textField.stringValue.isEmpty {
                    self.searchTextFieldView.textField.stringValue = ""
                    self.window?.makeFirstResponder(nil)
                }
            }
            .store(in: &cancellables)

        updateColors()
    }

    override func layout() {
        super.layout()
        backgroundEffectView.fillSuperview()
        searchTextFieldView.fillWidth().setHeight(25).alignBottom(0)
        tableView.fillSuperview().setY(searchTextFieldView.frame.minY)
        tableView.fillSuperview().extendToMaxY(searchTextFieldView.frame.minY)
        guidesShapeLayer.setFrame(.zero)

        if let emptyDataLabel, emptyDataLabel.isVisible {
            emptyDataLabel.fitSize().centerInSuperview()
        }
    }

    private func render(withDisplayItems displayItems: [LookinDisplayItem]) {
        self.displayItems = displayItems

        minIndentLevel = displayItems.map { $0.indentLevel() }.min() ?? 0

        tableView.reloadDataWithOffset()

        if displayItems.isEmpty {
            if emptyDataLabel == nil {
                let label = LKLabel()
                label.font = .systemFont(ofSize: 15)
                label.stringValue = NSLocalizedString("No Filter Results", comment: "")
                addSubview(label)
                emptyDataLabel = label
            }
            emptyDataLabel?.isHidden = false
            needsLayout = true
        } else {
            emptyDataLabel?.isHidden = true
        }
    }

    func scrollToMakeItemVisible(_ item: LookinDisplayItem?) {
        guard let item, let row = displayItems.firstIndex(where: { $0 === item }) else {
            return
        }
        tableView.scrollRowToVisible(row)
    }

    override func updateColors() {
        super.updateColors()
        guidesShapeLayer.strokeColor = isDarkMode ? NSColor(lookinRed: 255, green: 255, blue: 255, alpha: 0.3).cgColor : NSColor(lookinRed: 0, green: 0, blue: 0, alpha: 0.3).cgColor
    }

    private func exitAndClearSearch() {
        searchTextFieldView.textField.stringValue = ""

        window?.makeFirstResponder(nil)

        delegate?.hierarchyView(self, didInputSearchString: nil)
    }

    /// 激活搜索框
    func activateSearchBar() {
        searchTextFieldView.textField.becomeFirstResponder()
    }

    // MARK: - NSTableView

    func tableView(_ tableView: LKTableView, didHoverAtRow row: Int) {
        // 注意这里 item 可能为 nil
        delegate?.hierarchyView(self, didHoverAtItem: safeItem(atRow: row))
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        kRowHeight
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        displayItems.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard let item = safeItem(atRow: row) else {
            assertionFailure()
            return LKTableBlankRowView()
        }

        let view: LKHierarchyRowView
        if let reused = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("cell"), owner: self) as? LKHierarchyRowView {
            view = reused
        } else {
            view = LKHierarchyRowView(dataSource: dataSource)
            view.disclosureButton.onAction { [weak self] button in
                self?.handleDisclosureButton(button)
            }
            view.identifier = NSUserInterfaceItemIdentifier("cell")

            let menu = NSMenu()
            menu.autoenablesItems = true
            menu.lookin_bindObjectWeakly(view, forKey: kMenuBindKey_RowView)
            menu.delegate = self
            view.menu = menu
        }

        view.minIndentLevel = minIndentLevel
        view.displayItem = item

        view.disclosureButton.tag = row
        return view
    }

    func tableView(_ tableView: LKTableView, didSelectRow row: Int) {
        guard let item = safeItem(atRow: row) else {
            return
        }
        delegate?.hierarchyView(self, didSelectItem: item)

        DispatchQueue.main.async {
            self.bringGuidesLayerToFront()
        }
    }

    func tableView(_ tableView: LKTableView, didDoubleClickAtRow row: Int) {
        guard let item = safeItem(atRow: row) else {
            return
        }
        delegate?.hierarchyView(self, didDoubleClickItem: item)
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        let rowView = menu.lookin_getBindObject(forKey: kMenuBindKey_RowView) as? LKHierarchyRowView
        let displayItem = rowView?.displayItem

        menu.removeAllItems()
        if !(displayItem?.isUserCustom ?? false) {
            menu.addItem(NSMenuItem(title: NSLocalizedString("Focus", comment: "")) { [weak self] item in
                self?.handleFocusCurrentItem(item)
            })
            if !dataSource.isReadOnly {
                menu.addItem(NSMenuItem(title: NSLocalizedString("Print", comment: "")) { [weak self] item in
                    self?.handlePrintItem(item)
                })
            }

            menu.addItem(.separator())

            if !dataSource.isReadOnly {
                let isUpdating = LKStaticAsyncUpdateManager.sharedInstance.isUpdating
                let reloadItem = NSMenuItem()
                reloadItem.title = NSLocalizedString("Reload layer", comment: "")
                if !isUpdating {
                    reloadItem.onAction { [weak self] item in
                        self?.handleReloadSelfItem(item)
                    }
                }
                menu.addItem(reloadItem)

                let reloadChildrenItem = NSMenuItem()
                reloadChildrenItem.title = NSLocalizedString("Reload layer and its children", comment: "")
                if !isUpdating {
                    reloadChildrenItem.onAction { [weak self] item in
                        self?.handleReloadSelfAndChildrenItem(item)
                    }
                }
                menu.addItem(reloadChildrenItem)
            }
        }

        // 复制文字
        var stringsToCopy: [String] = []

        var doNotCopyTitle = false
        let title = displayItem?.title ?? ""
        if title.hasPrefix("UI") || title.hasPrefix("CA") {
            if (title as NSString).length < 10 {
                // 不显示常见的 UIView、CALayer 等系统类，避免干扰
                doNotCopyTitle = true
            }
        }
        if !doNotCopyTitle {
            stringsToCopy.append(title)
        }
        if let hostViewControllerName = displayItem?.hostViewControllerObject?.simpleDemangledClassName, !hostViewControllerName.isEmpty {
            stringsToCopy.append(hostViewControllerName)
        }
        if let ivarTraces = displayItem?.displayingObject()?.ivarTraces, !ivarTraces.isEmpty {
            let names = ivarTraces.map { trace -> String in
                let name = trace.ivarName ?? ""
                return name.hasPrefix("_") ? String(name.dropFirst()) : name
            }
            // lookin_nonredundantArray drops duplicates through an NSSet, so the order follows NSSet's.
            let ivarNames = NSSet(array: names).allObjects.compactMap { $0 as? String }
            stringsToCopy.append(contentsOf: ivarNames)
        }
        for (idx, string) in stringsToCopy.enumerated() {
            if idx == 0 {
                menu.addItem(.separator())
            }
            if string.isEmpty {
                assertionFailure("LKHierarchyView, menuNeedsUpdate, stringsToCopy length is zero.")
                continue
            }
            let item = NSMenuItem(title: String(format: NSLocalizedString("Copy text \"%@\"", comment: ""), string)) { item in
                guard let stringToCopy = item.representedObject as? String else { return }
                let paste = NSPasteboard.general
                paste.clearContents()
                paste.writeObjects([stringToCopy as NSString])
            }
            item.representedObject = string
            menu.addItem(item)
        }

        menu.addItem(.separator())
        if displayItem?.isExpandable == true {
            menu.addItem(NSMenuItem(title: NSLocalizedString("Expand recursively", comment: "")) { [weak self] item in
                self?.handleExpandRecursively(item)
            })
            menu.addItem(NSMenuItem(title: NSLocalizedString("Collapse children", comment: "")) { [weak self] item in
                self?.handleCollapseChildren(item)
            })
        }
        // 显示和隐藏图像
        menu.addItem(.separator())

        if let displayItem, displayItem.hasPreviewBoxAbility {
            if displayItem.inNoPreviewHierarchy {
                let title = displayItem.doNotFetchScreenshotReason == .fetchScreenshotPermitted ? NSLocalizedString("Show screenshot", comment: "") : NSLocalizedString("Show layer border", comment: "")
                menu.addItem(NSMenuItem(title: title) { [weak self] item in
                    self?.handleShowPreview(item)
                })
            } else {
                menu.addItem(NSMenuItem(title: NSLocalizedString("Hide screenshot this time", comment: "")) { [weak self] item in
                    self?.handleCancelPreview(item)
                })
            }
        }

        if !(displayItem?.isUserCustom ?? false) && !(displayItem?.inNoPreviewHierarchy ?? false) {
            menu.addItem(NSMenuItem(title: NSLocalizedString("Hide screenshot forever…", comment: "")) { _ in
                LKHelper.openCustomConfigWebsite()
            })
        }

        menu.addItem(.separator())

        if let displayItem, displayItem.groupScreenshot != nil {
            menu.addItem(NSMenuItem(title: NSLocalizedString("Export screenshot…", comment: "")) { item in
                let view = item.menu?.lookin_getBindObject(forKey: kMenuBindKey_RowView) as? LKHierarchyRowView
                LKExportManager.exportScreenshot(with: view?.displayItem)
            })
            let copyItem = NSMenuItem()
            copyItem.title = NSLocalizedString("Copy as PNG", comment: "")
            copyItem.submenu = copyAsPNGSubmenu(with: displayItem)
            menu.addItem(copyItem)
        }
    }

    private func copyAsPNGSubmenu(with displayItem: LookinDisplayItem) -> NSMenu {
        let nativeScale = LKExportManager.nativeScale(for: displayItem)
        let submenu = NSMenu()
        for scale in 1...3 {
            let pixelSize = LKExportManager.pixelSize(for: displayItem, scale: scale)
            let item = NSMenuItem(title: String(format: "%ldx (%ldx%ld)", scale, lround(pixelSize.width), lround(pixelSize.height))) { item in
                guard let displayItem = item.representedObject as? LookinDisplayItem else { return }
                LKExportManager.copyScreenshotAsPNG(with: displayItem, scale: item.tag)
            }
            item.representedObject = displayItem
            item.tag = scale
            item.isEnabled = scale <= nativeScale
            submenu.addItem(item)
        }
        return submenu
    }

    // MARK: - NSTextFieldDelegate

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // 按下了 esc 键
            exitAndClearSearch()
            return true
        }
        return false
    }

    // MARK: - Events Handler

    private func rowViewItem(of menuItem: NSMenuItem) -> LookinDisplayItem? {
        (menuItem.menu?.lookin_getBindObject(forKey: kMenuBindKey_RowView) as? LKHierarchyRowView)?.displayItem
    }

    private func handlePrintItem(_ menuItem: NSMenuItem) {
        NotificationCenter.default.post(name: LKAppShowConsoleNotificationName, object: rowViewItem(of: menuItem))
    }

    private func handleReloadSelfItem(_ menuItem: NSMenuItem) {
        guard let item = rowViewItem(of: menuItem) else {
            return
        }
        LKStaticAsyncUpdateManager.sharedInstance.reloadSingleDisplayItem(item)
    }

    private func handleReloadSelfAndChildrenItem(_ menuItem: NSMenuItem) {
        guard let item = rowViewItem(of: menuItem) else {
            return
        }
        LKStaticAsyncUpdateManager.sharedInstance.reloadDisplayItemAndChildren(item)
    }

    private func handleFocusCurrentItem(_ menuItem: NSMenuItem) {
        guard let item = rowViewItem(of: menuItem) else {
            assertionFailure()
            return
        }
        dataSource.focusDisplayItem(item)
    }

    private func handleShowPreview(_ menuItem: NSMenuItem) {
        LKTutorialManager.sharedInstance.togglePreview = true
        if let item = rowViewItem(of: menuItem) {
            delegate?.hierarchyView(self, needToShowPreviewOfItem: item)
        }
    }

    private func handleCancelPreview(_ menuItem: NSMenuItem) {
        LKTutorialManager.sharedInstance.togglePreview = true
        if let item = rowViewItem(of: menuItem) {
            delegate?.hierarchyView(self, needToCancelPreviewOfItem: item)
        }
    }

    private func handleExpandRecursively(_ menuItem: NSMenuItem) {
        guard let item = rowViewItem(of: menuItem) else {
            assertionFailure()
            return
        }
        delegate?.hierarchyView(self, needToExpandItem: item, recursively: true)
    }

    private func handleCollapseChildren(_ menuItem: NSMenuItem) {
        guard let item = rowViewItem(of: menuItem) else {
            assertionFailure()
            return
        }
        delegate?.hierarchyView(self, needToCollapseChildrenOfItem: item)
    }

    private func handleDisclosureButton(_ button: NSButton) {
        guard let item = safeItem(atRow: button.tag), item.isExpandable else {
            assertionFailure()
            return
        }
        if item.isExpanded {
            delegate?.hierarchyView(self, needToCollapseItem: item)
        } else {
            delegate?.hierarchyView(self, needToExpandItem: item, recursively: false)
        }
    }

    // MARK: - Guides

    func updateGuides(withHoveredItem item: LookinDisplayItem?) {
        guard let item else {
            guidesShapeLayer.isHidden = true
            return
        }

        let rootItem = item.`super`
        let rootRow = rootItem.flatMap { root in displayItems.firstIndex { $0 === root } }
        let childrenItems = (rootItem?.subitems ?? []).filter { child in displayItems.contains { $0 === child } }

        guard let rootItem, let rootRow, let lastChild = childrenItems.last else {
            guidesShapeLayer.isHidden = true
            return
        }

        let rootX = LKHierarchyRowView.disclosureMidX(withIndentLevel: rootItem.indentLevel() - minIndentLevel)
        let rootY = kRowHeight * CGFloat(rootRow) + kRowHeight / 2.0
        let lastChildRow = displayItems.firstIndex { $0 === lastChild } ?? 0
        let rootMaxY = CGFloat(lastChildRow) * kRowHeight + kRowHeight / 2.0
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rootX, y: rootY))
        path.addLine(to: CGPoint(x: rootX, y: rootMaxY))
        for obj in childrenItems {
            let row = displayItems.firstIndex { $0 === obj } ?? 0
            let childrenY = CGFloat(row) * kRowHeight + kRowHeight / 2.0
            path.move(to: CGPoint(x: rootX, y: childrenY))
            let maxX = obj.isExpandable ? (rootX + 10) : (rootX + 28)
            path.addLine(to: CGPoint(x: maxX, y: childrenY))
        }
        guidesShapeLayer.path = path
        guidesShapeLayer.isHidden = false
    }

    private func bringGuidesLayerToFront() {
        guidesShapeLayer.removeFromSuperlayer()
        tableView.contentView.documentView?.layer?.addSublayer(guidesShapeLayer)
    }

    // MARK: - Others

    private func safeItem(atRow row: Int) -> LookinDisplayItem? {
        displayItems.element(at: row)
    }
}
