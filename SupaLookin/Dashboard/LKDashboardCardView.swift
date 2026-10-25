//
//  LKDashboardCardView.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/18.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

protocol LKDashboardCardViewDelegate: AnyObject {
    func dashboardCardViewNeedToggleCollapse(_ view: LKDashboardCardView)
}

private let groupImages: [String: String] = [
    LookinAttrGroup_Class: "dashboard_class",
    LookinAttrGroup_Relation: "dashboard_relation",
    LookinAttrGroup_Layout: "dashboard_layout",
    LookinAttrGroup_AutoLayout: "dashboard_autolayout",
    LookinAttrGroup_ViewLayer: "dashboard_layer",
    LookinAttrGroup_UIImageView: "dashboard_imageview",
    LookinAttrGroup_UILabel: "dashboard_label",
    LookinAttrGroup_UIButton: "dashboard_button",
    LookinAttrGroup_UIControl: "dashboard_control",
    LookinAttrGroup_UIScrollView: "dashboard_scrollview",
    LookinAttrGroup_UITableView: "dashboard_tableview",
    LookinAttrGroup_UITextView: "dashboard_textview",
    LookinAttrGroup_UITextField: "dashboard_textfield",
    LookinAttrGroup_UIVisualEffectView: "dashboard_effectview",
    LookinAttrGroup_UIStackView: "dashboard_stackview",
    LookinAttrGroup_UserCustom: "dashboard_custom",
]

final class LKDashboardCardView: LKBaseView, LKUserActionManagerDelegate, LKDashboardAccessoryWindowControllerDelegate {

    weak var dashboardViewController: LKDashboardViewController?

    weak var delegate: LKDashboardCardViewDelegate?

    var attrGroup: LookinAttributesGroup?

    var isCollapsed = false {
        didSet {
            titleControl.disclosureImageView.image = NSImage(named: isCollapsed ? "icon_arrow_right" : "icon_arrow_down")
        }
    }

    private let backgroundEffectView = LKVisualEffectView()
    private let titleControl = LKDashboardCardTitleControl()
    private var detailButton: NSButton!
    private var relationHelpButton: NSButton?

    private var fadeView: LKBaseView?

    private let sectionViewPool = LKDashboardSectionViewPool()
    private var sectionViews: [LKDashboardSectionView] = []

    private var accessoryWC: LKDashboardAccessoryWindowController?

    private let titleHeight: CGFloat = 30
    private var contentsY: CGFloat = 35
    private let insetBottom: CGFloat = 12

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.cornerRadius = DashboardCardCornerRadius

        backgroundEffectView.blendingMode = .withinWindow
        backgroundEffectView.state = .active
        addSubview(backgroundEffectView)

        titleControl.clickAction = { [unowned self] _ in
            self.delegate?.dashboardCardViewNeedToggleCollapse(self)
        }
        addSubview(titleControl)

        detailButton = NSButton.imageButton(NSImage(named: "icon_more")) { [unowned self] _ in
            self.handleClickDetailButton()
        }
        detailButton.bezelStyle = .roundRect
        detailButton.isBordered = false
        addSubview(detailButton)

        updateColors()

        LKUserActionManager.sharedInstance.addDelegate(self)
    }

    override func layout() {
        super.layout()

        backgroundEffectView.fillSuperview()
        titleControl.fillWidth().setHeight(titleHeight).setY(0)
        if detailButton.isVisible {
            detailButton.setWidth(50).setHeight(28).alignRight(-3).setY(0)
        }
        if let relationHelpButton, relationHelpButton.isVisible {
            relationHelpButton.setWidth(30).setHeight(28).alignRight(5).setY(0)
        }

        if attrGroup == nil || sectionViews.isEmpty {
            return
        }

        var y = contentsY
        for view in sectionViews {
            view.setX(DashboardHorInset).extendToRight(DashboardHorInset).fitHeight().setY(y)
            y = view.frame.maxY + DashboardSectionMarginTop
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        if isCollapsed {
            size.height = titleHeight
            return size
        }
        size.width -= DashboardHorInset * 2
        var height = contentsY
        for view in sectionViews {
            let sectionHeight = view.sizeThatFits(size).height
            height += sectionHeight + DashboardSectionMarginTop
        }
        height -= DashboardSectionMarginTop
        height += insetBottom

        size.height = height
        return size
    }

    func render() {
        guard let attrGroup else {
            assertionFailure()
            return
        }
        if attrGroup.identifier == LookinAttrGroup_Class {
            contentsY = 28
        } else if attrGroup.identifier == LookinAttrGroup_Relation {
            contentsY = 30
        } else {
            contentsY = 35
        }

        titleControl.label.stringValue = attrGroup.queryDisplayTitle()
        titleControl.iconImageView.image = LKDashboardCardView.image(withAttrGroup: attrGroup)
        titleControl.needsLayout = true

        detailButton.isHidden = !shouldShowDetailButton(withGroupID: attrGroup.identifier)

        sectionViews.forEach { $0.removeFromSuperview() }
        sectionViews.removeAll()
        sectionViewPool.recycleAll()

        for (idx, sec) in (attrGroup.attrSections ?? []).enumerated() {
            if !sec.isUserCustom() && !LKPreferenceManager.mainManager.isSectionShowing(sec.identifier) {
                continue
            }

            let secView = sectionViewPool.dequeView(for: sec)
            sectionViews.append(secView)
            addSubview(secView)
            secView.dashboardViewController = dashboardViewController
            secView.attrSection = sec
            secView.showTopSeparator = idx > 0

            if accessoryWC != nil {
                secView.manageState = .canRemove
            } else {
                secView.manageState = .none
            }
        }

        if accessoryWC != nil {
            renderAccessoryWindowController()
        }

        if attrGroup.identifier == LookinAttrGroup_Relation {
            showRelationHelpButton()
        } else {
            hideRelationHelpButton()
        }

        needsLayout = true
    }

    func playFadeAnimation(withHighlightRect rect: CGRect) {
        if fadeView != nil {
            return
        }

        let fadeView = LKBaseView()
        fadeView.backgroundColor = isDarkMode ? NSColor(lookinRed: 0, green: 0, blue: 0, alpha: 0.7) : NSColor(lookinRed: 0, green: 0, blue: 0, alpha: 0.6)
        fadeView.alphaValue = 0
        fadeView.frame = bounds
        addSubview(fadeView)
        self.fadeView = fadeView

        if rect != .zero {
            var totalHeight = fadeView.frame.height
            if totalHeight <= 0 {
                assertionFailure()
                totalHeight = 1
            }

            let maskLayer = CAGradientLayer()
            maskLayer.colors = [NSColor.black.cgColor,
                                NSColor.black.cgColor,
                                NSColor.clear.cgColor,
                                NSColor.clear.cgColor,
                                NSColor.black.cgColor,
                                NSColor.black.cgColor]
            maskLayer.startPoint = CGPoint(x: 0, y: 0)
            maskLayer.endPoint = CGPoint(x: 0, y: 1)
            maskLayer.locations = [0,
                                   NSNumber(value: (rect.minY - 4) / totalHeight),
                                   NSNumber(value: (rect.minY + 10) / totalHeight),
                                   NSNumber(value: (rect.maxY + 2) / totalHeight),
                                   NSNumber(value: (rect.maxY + 16) / totalHeight),
                                   1]
            maskLayer.frame = fadeView.bounds
            fadeView.layer?.mask = maskLayer
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            fadeView.animator().alphaValue = 1
        }, completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.removeFadeAnimation()
            }
        })
    }

    private func removeFadeAnimation() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            self.fadeView?.animator().alphaValue = 0
        }, completionHandler: {
            // AppKit runs animation completion handlers on the main thread
            MainActor.assumeIsolated {
                self.fadeView?.removeFromSuperview()
                self.fadeView = nil
            }
        })
    }

    private static func image(withAttrGroup group: LookinAttributesGroup) -> NSImage? {
        let image = groupImages[group.identifier].flatMap { NSImage(named: $0) }
        assert(image != nil)
        return image
    }

    func querySectionView(with sec: LookinAttributesSection?) -> LKDashboardSectionView? {
        sectionViews.first { $0.attrSection === sec }
    }

    private func showRelationHelpButton() {
        if relationHelpButton == nil {
            let button = NSButton.imageButton(NSImage(named: "ic_question")) { [unowned self] _ in
                self.handleRelationHelpButton()
            }
            button.bezelStyle = .roundRect
            button.isBordered = false
            relationHelpButton = button
            addSubview(detailButton)
        }
        if let relationHelpButton {
            addSubview(relationHelpButton)
        }
    }

    private func hideRelationHelpButton() {
        relationHelpButton?.removeFromSuperview()
    }

    // MARK: - Others

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        LKUserActionManager.sharedInstance.sendAction(.dashboardClick)
    }

    // MARK: - LKUserActionManagerDelegate

    func userActionManager(_ manager: LKUserActionManager, didAct type: LKUserActionType) {
        guard let accessoryWC else {
            return
        }
        let validTypes: [LKUserActionType] = [.previewOperation, .dashboardClick, .selectedItemChange]
        if !validTypes.contains(type) {
            return
        }
        accessoryWC.close()
    }

    // MARK: - Accessory

    private func handleClickDetailButton() {
        if let accessoryWC {
            accessoryWC.close()
            return
        }

        LKUserActionManager.sharedInstance.sendAction(.dashboardClick)

        if isCollapsed {
            /// 如果当前是折叠状态，则展开
            delegate?.dashboardCardViewNeedToggleCollapse(self)
        }

        guard let groupID = attrGroup?.identifier else { return }
        let accessoryWC = LKDashboardAccessoryWindowController(dashboardController: dashboardViewController, attrGroupID: groupID)
        accessoryWC.delegate = self
        self.accessoryWC = accessoryWC

        renderAccessoryWindowController()

        if let accessoryWindow = accessoryWC.window {
            window?.addChildWindow(accessoryWindow, ordered: .above)
        }
    }

    private func renderAccessoryWindowController() {
        guard let accessoryWC, let attrGroup else {
            assertionFailure()
            return
        }

        sectionViews.forEach { $0.manageState = .canRemove }

        let allSecIDs = LookinDashboardBlueprint.sectionIDs(forGroupID: attrGroup.identifier) ?? []
        let hiddenSecIDs = allSecIDs.filter { !LKPreferenceManager.mainManager.isSectionShowing($0) }
        if hiddenSecIDs.isEmpty {
            accessoryWC.window?.contentView?.isHidden = true
            return
        }
        accessoryWC.window?.contentView?.isHidden = false

        let sections = hiddenSecIDs.compactMap { secID in
            attrGroup.attrSections?.first { $0.identifier == secID }
        }

        let contentSize = accessoryWC.render(withAttrSections: sections)

        guard let window else { return }
        // 这里是左上角坐标系，比如 cardView 顶部恰好和窗口顶部重合时，y 为 0
        let selfFrameInWindow = window.contentView?.convert(frame, from: superview) ?? .zero
        // 这里是左下角坐标系
        let selfWindowFrame = window.frame
        // 做个 MAX 以防止超出下边缘屏幕
        let panelY = max(selfWindowFrame.origin.y + (selfWindowFrame.size.height - selfFrameInWindow.origin.y) - contentSize.height, 0)
        var panelX = selfWindowFrame.maxX + 5
        let panelMaxX = panelX + contentSize.width
        if panelMaxX > (window.screen?.frame.size.width ?? 0) {
            // 防止超出屏幕右侧
            panelX = selfWindowFrame.origin.x + selfFrameInWindow.minX - contentSize.width - 5
        }
        let panelFrame = CGRect(x: panelX, y: panelY, width: contentSize.width, height: contentSize.height)
        // panelFrame 是左下角坐标系。虽然这里的 controller.window 是 self.window 的 childWindow，但 panelFrame 仍然是相对于 screen 的坐标，换句话说，如果 panelFrame.y 是 0，则 panel 的底部会和屏幕底部重合
        accessoryWC.window?.setFrame(panelFrame, display: true)
    }

    func dashboardAccessoryWindowControllerWillClose(_ controller: LKDashboardAccessoryWindowController) {
        sectionViews.forEach { $0.manageState = .none }
        accessoryWC = nil
    }

    private func shouldShowDetailButton(withGroupID identifier: String) -> Bool {
        if identifier == LookinAttrGroup_UserCustom {
            return false
        }
        let sectionCount = LookinDashboardBlueprint.sectionIDs(forGroupID: identifier)?.count ?? 0
        return sectionCount > 1
    }

    private func handleRelationHelpButton() {
        let menu = NSMenu()

        let menuItem = NSMenuItem(title: NSLocalizedString("How to display more member variables…", comment: "")) { _ in
            NSWorkspace.shared.open(URL(string: "https://bytedance.larkoffice.com/docx/CKRndHqdeoub11xSqUZcMlFhnWe")!)
        }
        menuItem.image = NSImage(named: "Icon_Inspiration_small")
        menu.addItem(menuItem)

        if let event = NSApplication.shared.currentEvent, let relationHelpButton {
            NSMenu.popUpContextMenu(menu, with: event, for: relationHelpButton)
        }
    }
}
