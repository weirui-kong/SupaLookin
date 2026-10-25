//
//  LKConstraintPopoverController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/9/28.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKConstraintPopoverController: LKBaseViewController {

    private var titleView: LKTextFieldView?
    private let textsView = LKTextsMenuView()
    private let constraint: LookinAutoLayoutConstraint

    private let horInset: CGFloat = 5
    private let insetBottom: CGFloat = 10
    private let titleHeight: CGFloat = 26
    private let textsViewMarginTop: CGFloat = 10

    var requestJumpingToObject: ((LookinObject) -> Void)?

    init(constraint: LookinAutoLayoutConstraint) {
        self.constraint = constraint
        super.init(containerView: nil)

        if !constraint.effective {
            let titleView = LKTextFieldView.labelView()
            titleView.textField.font = .systemFont(ofSize: LKHelper.isEnglish ? 12 : 13)
            titleView.textColors = LKTwoColors(lightMode: .lookinGray1, darkMode: .lookinGray9)
            titleView.textField.alignment = .center
            titleView.textField.stringValue = NSLocalizedString("The layout of selected view is not affected by this constraint.", comment: "")
            titleView.backgroundColors = LKTwoColors(lightMode: NSColor(lookinRed: 0, green: 0, blue: 0, alpha: 0.1), darkMode: NSColor(lookinRed: 0, green: 0, blue: 0, alpha: 0.2))
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

        var texts: [LookinStringTwoTuple] = []
        texts.append(LookinStringTwoTuple(first: "FirstItem", second: LookinAutoLayoutConstraint.description(withItemObject: constraint.firstItem, type: constraint.firstItemType, detailed: true)))
        texts.append(LookinStringTwoTuple(first: "FirstAttribute", second: LookinAutoLayoutConstraint.description(withAttributeInt: constraint.firstAttribute).capitalizedFirstLetter ?? ""))
        texts.append(LookinStringTwoTuple(first: "Relation", second: LookinAutoLayoutConstraint.description(withRelation: constraint.relation)))
        texts.append(LookinStringTwoTuple(first: "SecondItem", second: LookinAutoLayoutConstraint.description(withItemObject: constraint.secondItem, type: constraint.secondItemType, detailed: true)))
        texts.append(LookinStringTwoTuple(first: "SecondAttribute", second: LookinAutoLayoutConstraint.description(withAttributeInt: constraint.secondAttribute).capitalizedFirstLetter ?? ""))
        texts.append(LookinStringTwoTuple(first: "Multiplier", second: "\(NSNumber(value: constraint.multiplier))"))
        texts.append(LookinStringTwoTuple(first: "Constant", second: "\(NSNumber(value: constraint.constant))"))
        texts.append(LookinStringTwoTuple(first: "Priority", second: "\(NSNumber(value: constraint.priority))"))
        texts.append(LookinStringTwoTuple(first: "Active", second: constraint.active ? "YES" : "NO"))
        texts.append(LookinStringTwoTuple(first: "ShouldBeArchived", second: constraint.shouldBeArchived ? "YES" : "NO"))
        texts.append(LookinStringTwoTuple(first: "Identifier", second: constraint.identifier ?? ""))

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

    private func makeJumpButton(object: LookinObject?) -> NSButton {
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
