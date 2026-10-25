//
//  LKDashboardSearchMethodsView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/9/6.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

protocol LKDashboardSearchMethodsViewDelegate: AnyObject {
    func dashboardSearchMethodsView(_ view: LKDashboardSearchMethodsView, requestToInvokeMethod method: String, oid: UInt)
}

final class LKDashboardSearchMethodsView: LKDashboardSearchCardView {

    weak var delegate: LKDashboardSearchMethodsViewDelegate?

    private let titleLabel = LKLabel()
    private var errorLabel: LKLabel?
    private var itemViews: [LKTextControl] = []
    private var methodNames: [ObjectIdentifier: String] = [:]
    private var oid: UInt = 0

    private let insetTop: CGFloat = 5
    private let contentMarginTop: CGFloat = 10
    private let itemInterspace: CGFloat = 8

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.stringValue = NSLocalizedString("Click to invoke methods below and get the return value.", comment: "")
        addSubview(titleLabel)
    }

    override func layout() {
        super.layout()

        let width = frame.width - DashboardSearchCardInset * 2
        if titleLabel.isVisible {
            titleLabel.setX(DashboardSearchCardInset).setWidth(width).fitHeight().setY(insetTop)

            var y = titleLabel.frame.maxY + contentMarginTop
            for view in itemViews where !view.isHidden {
                let methodControlSize = view.sizeThatFits(NSSize(width: width, height: .greatestFiniteMagnitude))
                view.setSize(methodControlSize).setX(DashboardSearchCardInset).setY(y)
                y = view.frame.maxY + itemInterspace
            }

        } else if let errorLabel, errorLabel.isVisible {
            errorLabel.setX(DashboardSearchCardInset).setWidth(width).fitHeight().setY(insetTop)
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        let contentWidth = limitedSize.width - DashboardSearchCardInset * 2
        var size = limitedSize
        if titleLabel.isVisible {
            let height = titleLabel.height(forWidth: contentWidth) + insetTop + contentMarginTop
            size.height = itemViews.reduce(height) { accumulator, view in
                accumulator + view.height(forWidth: contentWidth) + itemInterspace
            }
        } else {
            size.height = (errorLabel?.height(forWidth: contentWidth) ?? 0) + insetTop * 2
        }

        return size
    }

    func render(withMethods methods: [String], oid: UInt) {
        self.oid = oid

        titleLabel.isHidden = false
        errorLabel?.isHidden = true

        itemViews.dequeue(count: methods.count, add: { _ in
            let control = LKTextControl()
            control.label.alignment = .left
            control.label.maximumNumberOfLines = 0
            control.adjustAlphaWhenClick = true
            control.clickAction = { [unowned self] control in
                self.handleMethodControl(control)
            }
            self.addSubview(control)
            return control
        }, notDequeued: { _, view in
            view.isHidden = true
        }, doNext: { idx, view in
            view.isHidden = false
            self.methodNames[ObjectIdentifier(view)] = methods[idx]
            view.label.attributedStringValue = LKAttributedStringBuilder(methods[idx]).font(size: 13).textColor(red: 74, green: 144, blue: 226).addImage(named: "icon_arrowRight_blue", baselineOffset: -1, marginLeft: 2, marginRight: 0).attributedString ?? NSAttributedString()
            view.needsLayout = true
        })

        needsLayout = true
    }

    func render(withError error: Error) {
        NSLog("%@", String(describing: error))
        itemViews.forEach { $0.isHidden = true }
        titleLabel.isHidden = true
        let label: LKLabel
        if let errorLabel {
            label = errorLabel
        } else {
            label = LKLabel()
            label.textColor = .labelColor
            label.font = .systemFont(ofSize: 12)
            addSubview(label)
            errorLabel = label
        }
        label.isHidden = false
        label.stringValue = NSLocalizedString("Failed to search related methods: ", comment: "") + error.localizedDescription
        needsLayout = true
    }

    private func handleMethodControl(_ control: NSControl) {
        guard let methodName = methodNames[ObjectIdentifier(control)], !methodName.isEmpty else {
            assertionFailure()
            return
        }
        delegate?.dashboardSearchMethodsView(self, requestToInvokeMethod: methodName, oid: oid)
    }
}
