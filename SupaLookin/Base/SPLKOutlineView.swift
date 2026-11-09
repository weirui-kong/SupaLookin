//
//  SPLKOutlineView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/28.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

protocol SPLKOutlineViewDelegate: AnyObject {
    func outlineView(_ view: SPLKOutlineView, configureRowView rowView: SPLKOutlineRowView, withItem item: SPLKOutlineItem)
}

final class SPLKOutlineView: SPLKBaseView, SPLKTableViewDelegate, SPLKTableViewDataSource {

    let tableView = SPLKTableView()

    var items: [SPLKOutlineItem]? {
        didSet {
            updateDisplayingItems()
        }
    }

    weak var delegate: SPLKOutlineViewDelegate?

    /// 默认为 24
    var itemHeight: CGFloat = 24

    private(set) var displayingItems: [SPLKOutlineItem] = []

    private let makeRowView: () -> SPLKOutlineRowView

    init(makeRowView: @escaping () -> SPLKOutlineRowView) {
        self.makeRowView = makeRowView
        super.init(frame: .zero)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.adjustsSelectionAutomatically = false
        addSubview(tableView)
    }

    convenience override init(frame frameRect: NSRect) {
        self.init { SPLKOutlineRowView(compactUI: false) }
    }

    override func layout() {
        super.layout()
        tableView.fillSuperview()
    }

    // MARK: - SPLKTableView

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

        let view: SPLKOutlineRowView
        if let reused = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("cell"), owner: self) as? SPLKOutlineRowView {
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
        displayingItems = SPLKOutlineItem.flatItems(fromRootItems: items)
        tableView.reloadData()
    }
}
