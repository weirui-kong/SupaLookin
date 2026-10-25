//
//  LKTableView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/4/20.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

protocol LKTableViewDataSource: AnyObject {
    func numberOfRows(in tableView: NSTableView) -> Int
}

/// The defaults stand in for the Objective-C protocol's unimplemented optional methods.
protocol LKTableViewDelegate: AnyObject {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView?
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool
    /// 以下方法的 row 均可能为 -1
    func tableView(_ tableView: LKTableView, didSelectRow row: Int)
    func tableView(_ tableView: LKTableView, didHoverAtRow row: Int)
    func tableView(_ tableView: LKTableView, didDoubleClickAtRow row: Int)
    /// 点击了空白处
    func tableViewDidClickBlankArea(_ tableView: LKTableView)
}

extension LKTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { 0 }
}

extension LKTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 0 }
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { nil }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { true }
    func tableView(_ tableView: LKTableView, didSelectRow row: Int) {}
    func tableView(_ tableView: LKTableView, didHoverAtRow row: Int) {}
    func tableView(_ tableView: LKTableView, didDoubleClickAtRow row: Int) {}
    func tableViewDidClickBlankArea(_ tableView: LKTableView) {}
}

private final class DisableKeyDownTableView: NSTableView {

    weak var responder: NSResponder?

    override func keyDown(with event: NSEvent) {
        responder?.keyDown(with: event)
    }
}

class LKTableView: NSScrollView, NSTableViewDelegate, NSTableViewDataSource {

    let tableView: NSTableView

    weak var delegate: LKTableViewDelegate?
    weak var dataSource: LKTableViewDataSource?

    /// 默认为 true
    var adjustsSelectionAutomatically = true

    /// 默认为 true
    var adjustsHoverAutomatically = true

    /// 默认为 true
    var canScrollHorizontally = true {
        didSet {
            hasHorizontalScroller = canScrollHorizontally
            if !canScrollHorizontally {
                horizontalScrollWidthManager = nil
            }
        }
    }

    private var horizontalScrollWidthManager: LKTableViewHorizontalScrollWidthManager?

    /// -1 表示不存在
    private var hoveredRow = -1 {
        didSet {
            guard oldValue != hoveredRow else {
                return
            }
            let prevHoveredRow = oldValue
            if prevHoveredRow >= 0 && prevHoveredRow < tableView.numberOfRows {
                (tableView.rowView(atRow: prevHoveredRow, makeIfNecessary: false) as? LKTableRowView)?.isHovered = false
            }
            if hoveredRow >= 0 && hoveredRow < tableView.numberOfRows {
                let canHover = delegate?.tableView(tableView, shouldSelectRow: hoveredRow) ?? true
                if canHover {
                    (tableView.rowView(atRow: hoveredRow, makeIfNecessary: false) as? LKTableRowView)?.isHovered = true
                }
            }
            delegate?.tableView(self, didHoverAtRow: hoveredRow)
        }
    }

    private var selectedRowStorage = -1

    private var selectedRow: Int {
        get {
            selectedRowStorage
        }
        set {
            guard adjustsSelectionAutomatically, selectedRowStorage != newValue else {
                return
            }
            let prevSelectedRow = selectedRowStorage
            selectedRowStorage = newValue

            if prevSelectedRow >= 0 && prevSelectedRow < tableView.numberOfRows {
                (tableView.rowView(atRow: prevSelectedRow, makeIfNecessary: false) as? LKTableRowView)?.isRowSelected = false
            }
            if newValue >= 0 && newValue < tableView.numberOfRows {
                (tableView.rowView(atRow: newValue, makeIfNecessary: false) as? LKTableRowView)?.isRowSelected = true
                delegate?.tableView(self, didSelectRow: newValue)
            }
        }
    }

    override init(frame frameRect: NSRect) {
        let table = DisableKeyDownTableView()
        tableView = table
        super.init(frame: frameRect)

        backgroundColor = .clear
        drawsBackground = false
        hasVerticalScroller = true
        autohidesScrollers = true

        table.responder = self
        tableView.style = .plain
        tableView.delegate = self
        tableView.dataSource = self
        tableView.wantsLayer = true
        tableView.backgroundColor = .clear
        tableView.headerView = nil
        tableView.focusRingType = .none
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("column"))
        column.isEditable = false
        tableView.addTableColumn(column)
        contentView.documentView = tableView
        tableActionForwarder.single = { [weak self] in
            self?.handleTableViewDefaultAction()
        }
        tableActionForwarder.double = { [weak self] in
            self?.handleDoubleClickTableView()
        }
        tableView.target = tableActionForwarder
        tableView.action = #selector(TableActionForwarder.performSingle(_:))
        tableView.doubleAction = #selector(TableActionForwarder.performDouble(_:))

        // canScrollHorizontally's didSet doesn't fire inside init
        hasHorizontalScroller = true
    }

    private let tableActionForwarder = TableActionForwarder()

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        guard canScrollHorizontally, let manager = horizontalScrollWidthManager else {
            tableView.fillWidth()
            return
        }
        if manager.maxRowWidth <= frame.width {
            tableView.fillWidth()
        } else {
            tableView.setWidth(manager.maxRowWidth + 20)
        }
    }

    func reloadData() {
        selectedRow = -1
        horizontalScrollWidthManager = nil
        if canScrollHorizontally {
            let manager = LKTableViewHorizontalScrollWidthManager()
            manager.didReachNewMaxWidth = { [weak self] in
                self?.handleRowViewMaxWidthChange()
            }
            horizontalScrollWidthManager = manager
        }
        tableView.reloadData()
    }

    /// reloadData 但是仍维持原本的滚动条位置（上面的 reloadData 会重置 offset）
    func reloadDataWithOffset() {
        let offset = documentVisibleRect.origin
        reloadData()
        needsLayout = true
        layoutSubtreeIfNeeded()
        documentView?.scroll(offset)
    }

    func scrollRowToVisible(_ row: Int) {
        tableView.scrollRowToVisible(row)
    }

    func makeView(withIdentifier identifier: String, owner: Any?) -> NSView? {
        tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: self)
    }

    private func handleRowViewMaxWidthChange() {
        guard canScrollHorizontally, let manager = horizontalScrollWidthManager else {
            return
        }
        if manager.maxRowWidth <= frame.width {
            return
        }
        tableView.setWidth(manager.maxRowWidth + 20)
    }

    // MARK: - Table View

    func numberOfRows(in tableView: NSTableView) -> Int {
        guard delegate != nil else {
            return 0
        }
        return dataSource?.numberOfRows(in: tableView) ?? 0
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        delegate?.tableView(tableView, heightOfRow: row) ?? 0
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard let rowView = delegate?.tableView(tableView, rowViewForRow: row) else {
            return nil
        }
        if let rowView = rowView as? LKTableRowView {
            rowView.isHovered = (hoveredRow == row)
            if adjustsSelectionAutomatically {
                rowView.isRowSelected = (selectedRow == row)
            }
            if canScrollHorizontally {
                rowView.horizontalScrollWidthManager = horizontalScrollWidthManager
            }
        }
        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        nil
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        delegate?.tableView(tableView, shouldSelectRow: row) ?? true
    }

    func tableViewSelectionIsChanging(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        if selectedRow < 0 {
            return
        }
        self.selectedRow = selectedRow

        if !adjustsSelectionAutomatically {
            delegate?.tableView(self, didSelectRow: selectedRow)
        }

        // 为什么加这一句呢？因为我们实际上不想依赖于 NSTableView 内建的 selectedRow 系统。想象这么一个场景：我们通过点击 NSTableView 把 selectedRow 变成了 10，然后通过点击 preview 选中了 row 20，但 NSTableView 仍然以为我们当前选中的是 10，于是当我们再次点击 NSTableView 的 row 10 时会发现 tableViewSelectionIsChanging: 不会被调用，因为 NSTableView 不认为 selectedRow 变化了。
        tableView.deselectRow(selectedRow)
    }

    // MARK: - Event Handler

    // tableViewSelectionIsChanging 会在 mouseDown 时被调用，而这个 handleTableViewDefaultAction 会在 mouseUp 时被调用，有点晚
    private func handleTableViewDefaultAction() {
        let clickedRow = tableView.clickedRow
        if clickedRow < 0 {
            delegate?.tableViewDidClickBlankArea(self)
        }
    }

    private func handleDoubleClickTableView() {
        delegate?.tableView(self, didDoubleClickAtRow: tableView.clickedRow)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        guard adjustsHoverAutomatically else {
            return
        }
        updateHoveredRow(with: event)
    }

    // 当鼠标离开了某一个 row 进入另一个 row 时，rowView 的 mouseExited 里的 super.mouseExited 这一句会调用到这里的这个方法
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard adjustsHoverAutomatically else {
            return
        }
        updateHoveredRow(with: event)
    }

    private func updateHoveredRow(with event: NSEvent) {
        let point = tableView.convert(event.locationInWindow, from: nil)
        hoveredRow = tableView.row(at: point)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        // The Objective-C code passed NSEventTypeMouseExited (raw 9) as a tracking option; the same raw bits are kept.
        let options: NSTrackingArea.Options = [NSTrackingArea.Options(rawValue: NSEvent.EventType.mouseExited.rawValue), .mouseMoved, .activeInKeyWindow, .inVisibleRect]
        let newArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(newArea)
    }
}

/// NSTableView sends `action` and `doubleAction` to one target.
private final class TableActionForwarder: NSObject {

    var single: (() -> Void)?
    var double: (() -> Void)?

    @objc func performSingle(_ sender: Any?) {
        single?()
    }

    @objc func performDouble(_ sender: Any?) {
        double?()
    }
}
