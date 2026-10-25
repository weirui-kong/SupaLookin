//
//  LKDashboardSectionView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/7.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

enum LKDashboardSectionManageState {
    case none
    case canAdd
    case canRemove
}

final class LKDashboardSectionView: LKBaseView {

    private var attrViews: [LKDashboardAttributeView] = []
    private var titleLabel: LKLabel?
    private let topSepLayer = CALayer()

    private var manageButton: NSButton?
    private var jsonPopupButton: NSButton?

    private let titleMarginTop: CGFloat = 6

    weak var dashboardViewController: LKDashboardViewController?

    var attrSection: LookinAttributesSection? {
        didSet {
            attrSectionDidChange()
        }
    }

    var showTopSeparator = false {
        didSet {
            topSepLayer.isHidden = !showTopSeparator
        }
    }

    var manageState: LKDashboardSectionManageState = .none {
        didSet {
            manageStateDidChange()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        /// 使得 topSepLayer 可以从右边延伸出去
        layer?.masksToBounds = false

        topSepLayer.lookin_removeImplicitAnimations()
        layer?.addSublayer(topSepLayer)

        updateColors()
    }

    override func layout() {
        super.layout()

        var contentsX: CGFloat = 0
        let selfWidth = frame.width
        var contentsY: CGFloat = 0

        if let manageButton, manageButton.isVisible {
            let y: CGFloat
            if topSepLayer.isHidden {
                y = 0
            } else if titleLabel?.isVisible == true {
                y = 6
            } else {
                y = 9
            }

            manageButton.fitSize().setX(0).setY(y)
            contentsX = manageButton.frame.maxX + 6
        }

        if let jsonPopupButton, jsonPopupButton.isVisible {
            jsonPopupButton.setWidth(30).setHeight(28).alignRight(-5).setY(0)
        }

        if !topSepLayer.isHidden {
            topSepLayer.setX(contentsX).setWidth(selfWidth).setHeight(1).setY(0)
            contentsY = DashboardAttrItemVerInterspace
        }

        if let titleLabel, titleLabel.isVisible {
            var titleWidth = selfWidth
            if jsonPopupButton?.isVisible == true {
                titleWidth -= 20
            }
            titleLabel.setX(contentsX).setWidth(titleWidth).fitHeight().setY(topSepLayer.isHidden ? 0 : titleMarginTop)
            contentsY = titleLabel.frame.maxY + DashboardAttrItemVerInterspace
        }

        let attrViews = self.attrViews.filter { $0.isVisible }
        for (idx, view) in attrViews.enumerated() {
            let prevView = idx > 0 ? attrViews[idx - 1] : nil
            let width: CGFloat
            let numberOfColumns = view.numberOfColumnsOccupied
            if numberOfColumns == 0 {
                width = view.sizeThatFits(.max).width
            } else {
                width = floor((selfWidth + DashboardAttrItemHorInterspace) / CGFloat(numberOfColumns)) - DashboardAttrItemHorInterspace
            }

            let x: CGFloat
            let y: CGFloat
            if let prevView, prevView.frame.maxX + DashboardAttrItemHorInterspace + width <= selfWidth + contentsX {
                x = prevView.frame.maxX + DashboardAttrItemHorInterspace
                y = prevView.frame.minY
            } else {
                x = contentsX
                y = prevView.map { $0.frame.maxY + DashboardAttrItemVerInterspace } ?? contentsY
            }
            view.setWidth(width).fitHeight().setX(x).setY(y)
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        let attrViews = self.attrViews.filter { $0.isVisible }

        var height: CGFloat = 0
        if !topSepLayer.isHidden {
            height += DashboardAttrItemVerInterspace
        }
        if let titleLabel, titleLabel.isVisible {
            var titleWidth = limitedSize.width
            if jsonPopupButton?.isVisible == true {
                titleWidth -= 20
            }
            height += titleLabel.sizeThatFits(NSSize(width: titleWidth, height: .greatestFiniteMagnitude)).height + titleMarginTop
        }
        var prevMaxX: CGFloat = 0
        for (idx, view) in attrViews.enumerated() {
            let numberOfColumns = view.numberOfColumnsOccupied
            let width: CGFloat
            if numberOfColumns == 0 {
                width = view.sizeThatFits(limitedSize).width
            } else {
                width = floor((limitedSize.width + DashboardAttrItemHorInterspace) / CGFloat(numberOfColumns)) - DashboardAttrItemHorInterspace
            }

            if idx > 0 && prevMaxX + DashboardAttrItemHorInterspace + width <= limitedSize.width {
                prevMaxX = prevMaxX + DashboardAttrItemHorInterspace + width
            } else {
                height += view.sizeThatFits(limitedSize).height
                if idx > 0 {
                    height += DashboardAttrItemVerInterspace
                }
                prevMaxX = width
            }
        }

        var size = limitedSize
        size.height = height
        return size
    }

    private func attrSectionDidChange() {
        guard let attrSection else {
            assertionFailure()
            return
        }

        if let title = resolveSectionTitle(), !title.isEmpty {
            let label: LKLabel
            if let titleLabel {
                label = titleLabel
                label.isHidden = false
            } else {
                label = LKLabel()
                label.font = .boldSystemFont(ofSize: 12)
                addSubview(label)
                titleLabel = label
            }
            label.stringValue = title
        } else {
            titleLabel?.isHidden = true
        }

        var notUsedViews = attrViews

        for attr in attrSection.attributes ?? [] {
            guard let attrViewClass = targetAttrClass(for: attr.attrType, identifier: attr.identifier) else {
                assertionFailure()
                continue
            }
            let view: LKDashboardAttributeView
            if let index = notUsedViews.firstIndex(where: { type(of: $0) == attrViewClass }) {
                view = notUsedViews.remove(at: index)
                view.isHidden = false
            } else {
                view = attrViewClass.init(frame: .zero)
                view.dashboardViewController = dashboardViewController
                attrViews.append(view)
                addSubview(view)
            }
            view.attribute = attr
        }

        notUsedViews.forEach { $0.isHidden = true }

        let hasJSONAttr = (attrSection.attributes ?? []).contains { $0.attrType == .json }
        if hasJSONAttr {
            showJSONPopupButton()
        } else {
            hideJSONPopupButton()
        }

        needsLayout = true
    }

    override func updateColors() {
        super.updateColors()
        topSepLayer.backgroundColor = isDarkMode ? NSColor.separatorDarkModeColor.cgColor : NSColor.separatorLightModeColor.cgColor
    }

    private func targetAttrClass(for type: LookinAttrType, identifier: String) -> LKDashboardAttributeView.Type? {
        switch type {
        case .cgRect:
            return LKDashboardAttributeRectView.self
        case .uiEdgeInsets:
            return LKDashboardAttributeInsetsView.self
        case .BOOL:
            return LKDashboardAttributeSwitchView.self
        case .float, .double, .long:
            return LKDashboardAttributeNumberInputView.self
        case .uiColor:
            return LKDashboardAttributeColorView.self
        case .enumInt, .enumLong, .enumString:
            return LKDashboardAttributeEnumsView.self
        case .cgPoint:
            return LKDashboardAttributePointView.self
        case .cgSize:
            return LKDashboardAttributeSizeView.self
        case .nsString:
            return LKDashboardAttributeTextView.self
        case .shadow:
            return LKDashboardAttributeShadowView.self
        case .json:
            return LKDashboardAttributeJsonView.self
        case .customObj:
            switch identifier {
            case LookinAttr_UITableView_RowsNumber_Number:
                return LKDashboardAttributeRowsCountView.self
            case LookinAttr_Class_Class_Class:
                return LKDashboardAttributeClassView.self
            case LookinAttr_Relation_Relation_Relation:
                return LKDashboardAttributeRelationView.self
            case LookinAttr_AutoLayout_Constraints_Constraints:
                return LKDashboardAttributeConstraintsView.self
            case LookinAttr_UIImageView_Open_Open:
                return LKDashboardAttributeOpenImageView.self
            case LookinAttr_UIVisualEffectView_Style_Style:
                return LKDashboardAttributeEnumsView.self
            default:
                assertionFailure()
                return nil
            }
        default:
            assertionFailure()
            return nil
        }
    }

    private func showJSONPopupButton() {
        if jsonPopupButton != nil {
            return
        }
        let button = NSButton.imageButton(NSImage(named: "open_newwindow")) { [unowned self] _ in
            self.handleJSONPopupButton()
        }
        button.bezelStyle = .roundRect
        button.isBordered = false
        addSubview(button)
        jsonPopupButton = button
    }

    private func hideJSONPopupButton() {
        jsonPopupButton?.removeFromSuperview()
    }

    private func handleJSONPopupButton() {
        let view = attrViews.first { $0.attribute?.attrType == .json }
        guard let jsonView = view as? LKDashboardAttributeJsonView else {
            assertionFailure()
            return
        }
        jsonView.showInNewWindow()
    }

    // MARK: - Manage

    private func manageStateDidChange() {
        if manageState == .none {
            manageButton?.isHidden = true
            needsLayout = true
            return
        }

        let image: NSImage?
        switch manageState {
        case .canAdd:
            image = NSImage(named: "icon_manage_add")
        case .canRemove:
            image = NSImage(named: "icon_manage_remove")
        case .none:
            return
        }

        if let manageButton {
            manageButton.image = image
            manageButton.isHidden = false
        } else {
            let button = NSButton.imageButton(image) { [unowned self] _ in
                self.handleManageButton()
            }
            button.bezelStyle = .roundRect
            button.isBordered = false
            addSubview(button)
            manageButton = button
        }
        needsLayout = true
    }

    private func handleManageButton() {
        guard let identifier = attrSection?.identifier else { return }
        let manager = LKPreferenceManager.mainManager
        switch manageState {
        case .canAdd:
            manager.showSection(identifier)
        case .canRemove:
            manager.hideSection(identifier)
        case .none:
            assertionFailure()
        }
    }

    private func resolveSectionTitle() -> String? {
        guard let attrSection else { return nil }
        if !attrSection.isUserCustom() {
            return LookinDashboardBlueprint.sectionTitle(withSectionID: attrSection.identifier)
        }
        guard let attr = attrSection.attributes?.first else {
            assertionFailure()
            return nil
        }
        switch attr.attrType {
        case .BOOL:
            return nil
        default:
            return attr.displayTitle
        }
    }
}
