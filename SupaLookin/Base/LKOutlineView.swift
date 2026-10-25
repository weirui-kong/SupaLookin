//
//  LKOutlineView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/28.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

protocol LKOutlineViewDelegate: AnyObject {
    func outlineView(_ view: LKOutlineView, configureRowView rowView: LKOutlineRowView, withItem item: LKOutlineItem)
}

final class LKOutlineView: LKBaseView, LKTableViewDelegate, LKTableViewDataSource {

    let tableView = LKTableView()

    var items: [LKOutlineItem]? {
        didSet {
            updateDisplayingItems()
        }
    }

    weak var delegate: LKOutlineViewDelegate?

    /// 默认为 24
    var itemHeight: CGFloat = 24

    private(set) var displayingItems: [LKOutlineItem] = []

    private let makeRowView: () -> LKOutlineRowView

    init(makeRowView: @escaping () -> LKOutlineRowView) {
        self.makeRowView = makeRowView
        super.init(frame: .zero)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.adjustsSelectionAutomatically = false
        addSubview(tableView)
    }

    convenience override init(frame frameRect: NSRect) {
        self.init { LKOutlineRowView(compactUI: false) }
    }

    override func layout() {
        super.layout()
        tableView.fillSuperview()
    }

    // MARK: - LKTableView

    func numberOfRows(in tableView: NSTableView) -> Int {
        displayingItems.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        itemHeight
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard let item = displayingItems.element(at: row) else {
            return makeRowView()
        }

        let view: LKOutlineRowView
        if let reused = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("cell"), owner: self) as? LKOutlineRowView {
            view = reused
        } else {
            view = makeRowView()
            view.identifier = NSUserInterfaceItemIdentifier("cell")
        }
        view.disclosureButton.tag = row
        view.disclosureButton.onAction { [weak self] button in
            self?.handleDisclosureButton(button)
        }

        switch item.status {
        case .notExpandable:
            view.status = .notExpandable
        case .expanded:
            view.status = .expanded
        case .collapsed:
            view.status = .collapsed
        }

        view.indentLevel = item.indentation
        view.titleLabel.stringValue = item.titleText ?? ""
        view.image = item.image

        delegate?.outlineView(self, configureRowView: view, withItem: item)

        view.needsLayout = true
        return view
    }

    // MARK: - Event Handler

    private func handleDisclosureButton(_ button: NSButton) {
        let row = button.tag
        guard let item = displayingItems.element(at: row), item.status != .notExpandable else {
            return
        }
        item.status = item.status == .expanded ? .collapsed : .expanded
        updateDisplayingItems()
    }

    // MARK: - Others

    private func updateDisplayingItems() {
        displayingItems = LKOutlineItem.flatItems(fromRootItems: items)
        tableView.reloadData()
    }
}
