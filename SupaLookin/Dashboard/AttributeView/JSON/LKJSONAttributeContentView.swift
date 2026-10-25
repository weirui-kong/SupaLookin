//
//  LKJSONAttributeContentView.swift
//  SupaLookin
//
//  Created by likai.123 on 2023/12/10.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

private final class LKJSONAttributeContentRowView: LKOutlineRowView {

    override class var insetLeft: CGFloat {
        0
    }
}

final class LKJSONAttributeContentView: LKBaseView, LKTableViewDelegate, LKTableViewDataSource {

    // Lookin never assigned this, so rows always use the small font.
    private let useBigFont = false
    private var rootItems: [LKJSONAttributeItem]?
    private var flatItems: [LKJSONAttributeItem] = []
    private let tableView = LKTableView()
    private let rowHeight: CGFloat

    var didReloadData: (() -> Void)?

    init(bigFont: Bool) {
        rowHeight = bigFont ? 25 : 20
        super.init(frame: .zero)
        tableView.drawsBackground = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.adjustsSelectionAutomatically = false
        tableView.adjustsHoverAutomatically = false
        tableView.automaticallyAdjustsContentInsets = false
        if bigFont {
            tableView.contentInsets = NSEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        } else {
            tableView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
        addSubview(tableView)
    }

    override func layout() {
        super.layout()
        tableView.fillSuperview()
    }

    func render(withJSON json: String?) {
        buildModel(json)
        render()
    }

    private func buildModel(_ json: String?) {
        rootItems = nil

        guard let json else {
            return
        }
        rootItems = LKJSONAttributeItem.rootItems(fromJSON: json)
    }

    private func render() {
        flatItems = (rootItems ?? []).flatMap { $0.flatItems() }

        tableView.reloadData()
    }

    // MARK: - LKTableView

    func numberOfRows(in tableView: NSTableView) -> Int {
        flatItems.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        rowHeight
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard let item = flatItems.element(at: row) else {
            return LKTableBlankRowView()
        }

        let identifier = NSUserInterfaceItemIdentifier("myView")
        let view: LKJSONAttributeContentRowView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? LKJSONAttributeContentRowView {
            view = reused
        } else {
            view = LKJSONAttributeContentRowView(compactUI: true)
            view.titleLabel.textColor = .secondaryLabelColor
            if useBigFont {
                view.titleLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
                view.subtitleLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
            } else {
                view.titleLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
                view.subtitleLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            }

            view.titleLabel.isSelectable = true
            view.subtitleLabel.textColor = .labelColor
            view.subtitleLabel.isSelectable = true
            view.disclosureButton.onAction { [unowned self] button in
                self.handleExpand(button)
            }
            view.identifier = identifier
        }
        view.titleLabel.stringValue = item.titleText ?? ""
        view.subtitleLabel.stringValue = item.desc ?? ""
        view.disclosureButton.tag = row
        view.indentLevel = item.indentation
        if (item.subItems?.count ?? 0) > 0 {
            view.status = item.expanded ? .expanded : .collapsed
        } else {
            view.status = .notExpandable
        }
        view.needsLayout = true
        return view
    }

    private func handleExpand(_ button: NSButton) {
        guard let item = flatItems.element(at: button.tag) else {
            return
        }
        item.expanded = !item.expanded
        render()

        didReloadData?()
    }

    func queryContentHeight() -> CGFloat {
        CGFloat(flatItems.count) * rowHeight
    }
}
