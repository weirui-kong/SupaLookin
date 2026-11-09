//
//  SPLKJSONAttributeViewController.swift
//  SupaLookin
//
//  Created by likai.123 on 2023/12/4.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class SPLKJSONAttributeViewController: SPLKBaseViewController, SPLKTableViewDelegate, SPLKTableViewDataSource {

    private var rootItems: [SPLKJSONAttributeItem]?
    private var flatItems: [SPLKJSONAttributeItem] = []
    private var tableView: SPLKTableView!

    override func makeContainerView() -> NSView {
        let containerView = SPLKBaseView()

        tableView = SPLKTableView()
        tableView.drawsBackground = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.canScrollHorizontally = false
        tableView.adjustsSelectionAutomatically = false
        tableView.adjustsHoverAutomatically = false
        tableView.automaticallyAdjustsContentInsets = false
        tableView.contentInsets = NSEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        containerView.addSubview(tableView)

        return containerView
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        tableView.fillSuperview().extendToY(28)
    }

    func render(withJSON json: String) {
        buildModel(json)
        render()
    }

    private func buildModel(_ json: String) {
        rootItems = nil
        rootItems = SPLKJSONAttributeItem.rootItems(fromJSON: json)
    }

    private func render() {
        flatItems = (rootItems ?? []).flatMap { $0.flatItems() }

        tableView.reloadData()
    }

    // MARK: - SPLKTableView

    func numberOfRows(in tableView: NSTableView) -> Int {
        flatItems.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        25
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard let item = flatItems.element(at: row) else {
            return SPLKTableBlankRowView()
        }

        let identifier = NSUserInterfaceItemIdentifier("myView")
        let view: SPLKOutlineRowView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? SPLKOutlineRowView {
            view = reused
        } else {
            view = SPLKOutlineRowView()
            view.titleLabel.textColor = .secondaryLabelColor
            view.titleLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
            view.titleLabel.isSelectable = true
            view.subtitleLabel.textColor = .labelColor
            view.subtitleLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
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
    }
}
