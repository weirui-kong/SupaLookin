//
//  LKInputSearchSuggestionsContentView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/3.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

private let kInputSearchSuggestionsItemViewHeight: CGFloat = 28

final class LKInputSearchSuggestionsContentView: LKBaseView, NSTableViewDelegate, NSTableViewDataSource {

    private let backgroundEffectView = LKVisualEffectView()

    let tableView = NSTableView()

    private lazy var calculatingRowView = LKInputSearchSuggestionsRowView()

    var items: [LKInputSearchSuggestionItem]? {
        didSet {
            tableView.reloadData()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.cornerRadius = 4

        backgroundEffectView.blendingMode = .behindWindow
        backgroundEffectView.state = .active
        addSubview(backgroundEffectView)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.wantsLayer = true
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("column"))
        column.isEditable = false
        tableView.addTableColumn(column)
        addSubview(tableView)
    }

    override func layout() {
        super.layout()
        backgroundEffectView.fillSuperview()
        tableView.fillSuperview()
    }

    func currentSelectedItem() -> LKInputSearchSuggestionItem? {
        items?.element(at: tableView.selectedRow)
    }

    func bestSize() -> NSSize {
        let rowView = calculatingRowView
        let items = items ?? []
        let width = items.reduce(CGFloat(0)) { accumulator, item in
            rowView.imageView.image = item.image
            rowView.titleLabel.stringValue = item.text ?? ""
            return max(rowView.bestWidth(), accumulator)
        }
        let height = kInputSearchSuggestionsItemViewHeight * CGFloat(items.count)
        return NSSize(width: width, height: height)
    }

    // MARK: - Table View

    func numberOfRows(in tableView: NSTableView) -> Int {
        items?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        kInputSearchSuggestionsItemViewHeight
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard let item = items?.element(at: row) else {
            return LKInputSearchSuggestionsRowView()
        }
        let view: LKInputSearchSuggestionsRowView
        if let reused = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("cell"), owner: self) as? LKInputSearchSuggestionsRowView {
            view = reused
        } else {
            view = LKInputSearchSuggestionsRowView()
            view.identifier = NSUserInterfaceItemIdentifier("cell")
        }
        view.titleLabel.stringValue = item.text ?? ""
        view.imageView.image = item.image
        view.needsLayout = true
        return view
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        nil
    }
}
