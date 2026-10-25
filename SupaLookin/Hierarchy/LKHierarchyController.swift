//
//  LKHierarchyController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/12.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

class LKHierarchyController: LKBaseViewController, LKHierarchyViewDelegate {

    let dataSource: LKHierarchyDataSource
    let hierarchyView: LKHierarchyView

    init(dataSource: LKHierarchyDataSource) {
        let hierarchyView = LKHierarchyView(dataSource: dataSource)
        self.dataSource = dataSource
        self.hierarchyView = hierarchyView
        super.init(containerView: hierarchyView)
        hierarchyView.delegate = self
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        let tutorial = LKTutorialManager.sharedInstance
        if !tutorial.hasAlreadyShowedTipsThisLaunch && !tutorial.copyTitle {
            if let selectedView = currentSelectedRowView() {
                tutorial.hasAlreadyShowedTipsThisLaunch = true
                tutorial.showPopover(ofView: selectedView, text: NSLocalizedString("You can copy ivar or class name in right-cick menu.", comment: "")) {
                    LKTutorialManager.sharedInstance.copyTitle = true
                }
            }
        }
        if !tutorial.hasAlreadyShowedTipsThisLaunch && !tutorial.eventsHandler {
            // 第一个 row 一般是 UIWindow，上面肯定是有手势的
            guard let rowView = hierarchyView.tableView.tableView.rowView(atRow: 0, makeIfNecessary: false) as? LKHierarchyRowView else {
                return
            }
            if (rowView.displayItem?.eventHandlers?.count ?? 0) > 0, let eventHandlerButton = rowView.eventHandlerButton {
                tutorial.hasAlreadyShowedTipsThisLaunch = true
                tutorial.eventsHandler = true
                tutorial.showPopover(ofView: eventHandlerButton, text: "这个蓝色图标表示存在 GestureRecognizer 等事件处理器，可点击这个蓝色图标查看详情") {
                    LKTutorialManager.sharedInstance.eventsHandler = true
                }
            }
        }
    }

    func currentSelectedRowView() -> NSView? {
        let row = dataSource.row(for: dataSource.selectedItem)
        if row == NSNotFound {
            return nil
        }
        return hierarchyView.tableView.tableView.rowView(atRow: row, makeIfNecessary: false)
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if dataSource.keyDown(event) {
            return
        }
        super.keyDown(with: event)
    }

    // MARK: - LKHierarchyViewDelegate

    func hierarchyView(_ view: LKHierarchyView, didSelectItem item: LookinDisplayItem) {
        dataSource.selectedItem = item
    }

    func hierarchyView(_ view: LKHierarchyView, didDoubleClickItem item: LookinDisplayItem) {
        let hasShowedAsk = LKPreferenceManager.popupToAskDoubleClickBehaviorIfNeeded(with: self.view.window)
        if hasShowedAsk {
            return
        }
        switch LKPreferenceManager.mainManager.doubleClickBehavior {
        case .collapse:
            if !item.isExpandable {
                return
            }
            if item.isExpanded {
                dataSource.collapseItem(item)
            } else {
                dataSource.expandItem(item)
            }
        case .focus:
            dataSource.focusDisplayItem(item)
        }
    }

    /// 注意这里 item 可能为 nil
    func hierarchyView(_ view: LKHierarchyView, didHoverAtItem item: LookinDisplayItem?) {
        dataSource.hoveredItem = item
    }

    func hierarchyView(_ view: LKHierarchyView, needToCollapseItem item: LookinDisplayItem) {
        dataSource.collapseItem(item)
    }

    func hierarchyView(_ view: LKHierarchyView, needToCollapseChildrenOfItem item: LookinDisplayItem) {
        dataSource.collapseAllChildren(of: item)
    }

    func hierarchyView(_ view: LKHierarchyView, needToExpandItem item: LookinDisplayItem, recursively: Bool) {
        if recursively {
            dataSource.expandItemsRooted(by: item)
        } else {
            dataSource.expandItem(item)
        }
    }

    func hierarchyView(_ view: LKHierarchyView, didInputSearchString string: String?) {
        NSLog("search string:%@", string ?? "(null)")
        if let string, !string.isEmpty {
            dataSource.search(with: string)
        } else {
            dataSource.endSearch()
            if dataSource.selectedItem != nil {
                // 结束搜索，滚动到选中的 item
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.hierarchyView.scrollToMakeItemVisible(self.dataSource.selectedItem)
                }
            }
        }
    }

    // The Objective-C protocol made these two optional; LKStaticHierarchyController and LKReadHierarchyController override them.
    func hierarchyView(_ view: LKHierarchyView, needToCancelPreviewOfItem item: LookinDisplayItem) {}

    func hierarchyView(_ view: LKHierarchyView, needToShowPreviewOfItem item: LookinDisplayItem) {}
}
