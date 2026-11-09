//
//  SPLKConstraintPopoverController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/9/28.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import SPLKServer

final class SPLKConstraintPopoverController: SPLKBaseViewController {

    private var titleView: SPLKTextFieldView?
    private let textsView = SPLKTextsMenuView()
    private let constraint: SPLKAutoLayoutConstraint

    private let horInset: CGFloat = 5
    private let insetBottom: CGFloat = 10
    private let titleHeight: CGFloat = 26
    private let textsViewMarginTop: CGFloat = 10

    var requestJumpingToObject: ((SPLKObject) -> Void)?

    init(constraint: SPLKAutoLayoutConstraint) {
        self.constraint = constraint
        super.init(containerView: nil)

        if !constraint.effective {
            let titleView = SPLKTextFieldView.labelView()
            titleView.textField.font = .systemFont(ofSize: SPLKHelper.isEnglish ? 12 : 13)
            titleView.textColors = SPLKTwoColors(lightMode: .splkGray1, darkMode: .splkGray9)
            titleView.textField.alignment = .center
            titleView.textField.stringValue = NSLocalizedString("The layout of selected view is not affected by this constraint.", comment: "")
            titleView.backgroundColors = SPLKTwoColors(lightMode: NSColor(splkRed: 0, green: 0, blue: 0, alpha: 0.1), darkMode: NSColor(splkRed: 0, green: 0, blue: 0, alpha: 0.2))
            titleView.image = NSImage(named: "Constraint_Popover_Info")
            titleView.insets = NSEdgeInsets(top: 0, left: horInset, bottom: 0, right: horInset)
            view.addSubview(titleView)
            self.titleView = titleView
        }

        textsView.verSpace = 8
        textsView.horSpace = 4
        textsView.font = .systemFont(ofSize: 13)
        textsView.type = .center
        view.addSubview(textsView)

        var texts: [SPLKStringTwoTuple] = []
        texts.append(SPLKStringTwoTuple(first: "FirstItem", second: SPLKAutoLayoutConstraint.description(withItemObject: constraint.firstItem, type: constraint.firstItemType, detailed: true)))
        texts.append(SPLKStringTwoTuple(first: "FirstAttribute", second: SPLKAutoLayoutConstraint.description(withAttributeInt: constraint.firstAttribute).capitalizedFirstLetter ?? ""))
        texts.append(SPLKStringTwoTuple(first: "Relation", second: SPLKAutoLayoutConstraint.description(withRelation: constraint.relation)))
        texts.append(SPLKStringTwoTuple(first: "SecondItem", second: SPLKAutoLayoutConstraint.description(withItemObject: constraint.secondItem, type: constraint.secondItemType, detailed: true)))
        texts.append(SPLKStringTwoTuple(first: "SecondAttribute", second: SPLKAutoLayoutConstraint.description(withAttributeInt: constraint.secondAttribute).capitalizedFirstLetter ?? ""))
        texts.append(SPLKStringTwoTuple(first: "Multiplier", second: "\(NSNumber(value: constraint.multiplier))"))
        texts.append(SPLKStringTwoTuple(first: "Constant", second: "\(NSNumber(value: constraint.constant))"))
        texts.append(SPLKStringTwoTuple(first: "Priority", second: "\(NSNumber(value: constraint.priority))"))
        texts.append(SPLKStringTwoTuple(first: "Active", second: constraint.active ? "YES" : "NO"))
        texts.append(SPLKStringTwoTuple(first: "ShouldBeArchived", second: constraint.shouldBeArchived ? "YES" : "NO"))
        texts.append(SPLKStringTwoTuple(first: "Identifier", second: constraint.identifier ?? ""))

        if constraint.firstItemType == .view {
            let button = makeJumpButton(object: constraint.firstItem)
            textsView.addButton(button, at: 0)
        }
        if constraint.secondItemType == .view {
            // Lookin binds firstItem here too, so both buttons jump to the first item.
            let button = makeJumpButton(object: constraint.firstItem)
            textsView.addButton(button, at: 3)
        }

        textsView.texts = texts
    }

    private func makeJumpButton(object: SPLKObject?) -> NSButton {
        NSButton.imageButton(NSImage(named: "Icon_JumpDisclosure")) { [weak self] _ in
            guard let object else {
                assertionFailure()
                return
            }
            self?.requestJumpingToObject?(object)
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        titleView?.fillWidth().setHeight(titleHeight).setY(0)

        let y = titleView != nil ? titleHeight : 0
        textsView.fitSize().centerHorizontally().setY(y + textsViewMarginTop)
    }

    func contentSize() -> NSSize {
        var resultSize = textsView.sizeThatFits(.max)

        if let titleView {
            let titleWidth = titleView.sizeThatFits(.max).width
            resultSize.width = max(titleWidth, resultSize.width)
            resultSize.height += titleHeight
        }

        resultSize.width += horInset * 2
        resultSize.height += insetBottom + textsViewMarginTop

        return resultSize
    }
}
