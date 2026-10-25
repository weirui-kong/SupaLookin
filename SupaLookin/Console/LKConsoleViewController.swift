//
//  LKConsoleViewController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/4/19.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import LookinShared

final class LKConsoleViewController: LKBaseViewController, LKTableViewDelegate, LKTableViewDataSource {

    private let dataSource: LKConsoleDataSource
    private var tableView: LKTableView!
    private var clearButton: NSButton!

    private var inputRowView: LKConsoleInputRowView!
    private var topBorderLayer: CALayer!

    private var prevWidth: CGFloat = 0
    private lazy var calculatingReturnRowView = LKConsoleReturnRowView()

    var isControllerShowing: Bool {
        get { dataSource.isShowingConsole }
        set { dataSource.isShowingConsole = newValue }
    }

    init(hierarchyDataSource dataSource: LKHierarchyDataSource) {
        self.dataSource = LKConsoleDataSource(hierarchyDataSource: dataSource)

        super.init(containerView: nil)

        self.dataSource.rowItemsPublisher
            .sink { [weak self] _ in
                guard let self else { return }
                self.tableView.reloadData()
                self.tableView.layoutSubtreeIfNeeded()

                if !self.dataSource.rowItems.isEmpty {
                    self.tableView.scrollRowToVisible(self.dataSource.rowItems.count - 1)
                }
                self.inputRowView.makeTextFieldAsFirstResponder()
            }
            .store(in: &cancellables)
    }

    override func makeContainerView() -> NSView {
        let containerView = LKBaseView()
        containerView.backgroundColorName = "ConsoleBackgroundColor"

        inputRowView = LKConsoleInputRowView(dataSource: dataSource)

        tableView = LKTableView()
        tableView.drawsBackground = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.canScrollHorizontally = false
        tableView.adjustsSelectionAutomatically = false
        tableView.adjustsHoverAutomatically = false
        tableView.automaticallyAdjustsContentInsets = false
        tableView.contentInsets = NSEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        containerView.addSubview(tableView)

        let clearButtonImage = NSImage(named: "icon_delete")
        clearButtonImage?.isTemplate = true
        clearButton = NSButton()
        clearButton.image = clearButtonImage
        clearButton.bezelStyle = .roundRect
        clearButton.isBordered = false
        clearButton.onAction { [unowned self] _ in
            self.dataSource.clearHistoryContents()
        }
        containerView.addSubview(clearButton)

        topBorderLayer = CALayer()
        topBorderLayer.lookin_removeImplicitAnimations()
        containerView.layer?.addSublayer(topBorderLayer)
        containerView.didChangeAppearanceBlock = { [weak self] _, isDarkMode in
            if isDarkMode {
                self?.topBorderLayer?.backgroundColor = NSColor(white: 1, alpha: 0.12).cgColor
            } else {
                self?.topBorderLayer?.backgroundColor = NSColor(white: 0, alpha: 0.15).cgColor
            }
        }

        return containerView
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.tableView.scrollRowToVisible(self.dataSource.rowItems.count - 1)
            self.inputRowView.makeTextFieldAsFirstResponder()
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        topBorderLayer.fillWidth().setHeight(1).setY(0)

        tableView.fillSuperview()
        clearButton.fitSize().alignRight(20).alignBottom(8)

        if prevWidth != view.frame.width {
            prevWidth = view.frame.width
            tableView.reloadData()
        }
    }

    func submit(withObj obj: LookinObject?, text: String) {
        Task {
            do {
                try await dataSource.submit(withObj: obj, text: text)
            } catch {
                NSLog("Submit error: %@", String(describing: error))
            }
        }
    }

    // MARK: - LKTableView

    func numberOfRows(in tableView: NSTableView) -> Int {
        dataSource.rowItems.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard let item = dataSource.rowItems.element(at: row) else {
            return 0
        }
        switch item.type {
        case .input:
            return 20
        case .submit:
            return 20
        case .return:
            calculatingReturnRowView.titleLabel.stringValue = item.normalText ?? ""
            return calculatingReturnRowView.height(forWidth: self.tableView.frame.width)
        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard let item = dataSource.rowItems.element(at: row) else {
            return LKTableBlankRowView()
        }

        switch item.type {
        case .input:
            return inputRowView

        case .submit:
            let identifier = NSUserInterfaceItemIdentifier("submit")
            let view = tableView.makeView(withIdentifier: identifier, owner: self) as? LKConsoleSubmitRowView ?? {
                let view = LKConsoleSubmitRowView()
                view.identifier = identifier
                return view
            }()
            view.titleLabel.stringValue = item.highlightText ?? ""
            view.subtitleLabel.stringValue = item.normalText ?? ""
            view.needsLayout = true
            return view

        case .return:
            let identifier = NSUserInterfaceItemIdentifier("return")
            let view = tableView.makeView(withIdentifier: identifier, owner: self) as? LKConsoleReturnRowView ?? {
                let view = LKConsoleReturnRowView()
                view.identifier = identifier
                return view
            }()
            view.titleLabel.stringValue = item.normalText ?? ""
            view.needsLayout = true
            return view
        }
    }

    func tableViewDidClickBlankArea(_ tableView: LKTableView) {
        inputRowView.makeTextFieldAsFirstResponder()
    }
}
