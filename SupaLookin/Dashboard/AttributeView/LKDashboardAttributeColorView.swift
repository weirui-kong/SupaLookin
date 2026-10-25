//
//  LKDashboardAttributeColorView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/2/21.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import LookinShared

private final class LKDashboardAttributeColorContainerView: LKBaseView {

    var clickAction: ((NSEvent) -> Void)?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        clickAction?(event)
    }
}

final class LKDashboardAttributeColorView: LKDashboardAttributeView, NSMenuDelegate {

    private let indicatorLayer = LKColorIndicatorLayer()
    private let descLabel = LKLabel()
    private let containerView = LKDashboardAttributeColorContainerView()
    private let iconImageView = NSImageView()
    private var aliasLabel: LKLabel?

    private let identifiersToHideAlias: [String] = [LookinAttr_ViewLayer_Border_Color, LookinAttr_ViewLayer_Shadow_Color]

    private let mainContainerHeight: CGFloat = 30
    private let aliasLabelMarginTop: CGFloat = 1
    private let labelX: CGFloat = 28

    private var cancellables = Set<AnyCancellable>()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        containerView.layer?.cornerRadius = DashboardCardControlCornerRadius
        containerView.clickAction = { [unowned self] event in
            self.handleClick(event)
        }
        addSubview(containerView)

        containerView.layer?.addSublayer(indicatorLayer)

        iconImageView.image = NSImage(named: "Icon_ArrowUpDown")
        containerView.addSubview(iconImageView)

        descLabel.textColor = NSColor(named: "DashboardCardValueColor")
        descLabel.font = .systemFont(ofSize: 13)
        containerView.addSubview(descLabel)

        LKPreferenceManager.mainManager.rgbaFormatPublisher
            .dropFirst()
            .sink { [weak self] _ in
                self?.renderWithAttribute()
            }
            .store(in: &cancellables)
    }

    override func layout() {
        super.layout()
        containerView.fillWidth().setHeight(mainContainerHeight).setY(0)
        indicatorLayer.setWidth(16).setHeight(16).setX(8).centerVertically()
        descLabel.setX(labelX).extendToRight(20).fitHeight().centerVertically().offset(y: -1)
        iconImageView.fitSize().centerVertically().alignRight(9)
        if let aliasLabel, aliasLabel.isVisible {
            aliasLabel.setX(labelX).extendToRight(0).setY(containerView.frame.maxY + aliasLabelMarginTop).fitHeight()
        }
    }

    override func renderWithAttribute() {
        iconImageView.isHidden = !canEdit()

        let color = NSColor.color(fromRGBAComponents: attribute?.value as? [Any])
        indicatorLayer.color = color

        if let color {
            descLabel.stringValue = LKPreferenceManager.mainManager.rgbaFormat ? color.rgbaString : color.hexString
        } else {
            descLabel.stringValue = "nil"
        }

        let dataSource = dashboardViewController?.currentDataSource()
        let alias = dataSource?.alias(for: color)
        if let alias, !identifiersToHideAlias.contains(attribute?.identifier ?? "") {
            let label: LKLabel
            if let aliasLabel {
                label = aliasLabel
            } else {
                label = LKLabel()
                label.textColor = NSColor(named: "DashboardCardValueColor")
                addSubview(label)
                aliasLabel = label
            }
            label.isHidden = false
            label.attributedStringValue = LKAttributedStringBuilder(alias.joined(separator: "\n")).font(.systemFont(ofSize: 11)).lineHeight(18).attributedString ?? NSAttributedString()
        } else {
            aliasLabel?.isHidden = true
        }
        needsLayout = true
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var height = mainContainerHeight
        if let aliasLabel, aliasLabel.isVisible {
            let width = limitedSize.width - labelX
            height += aliasLabelMarginTop + aliasLabel.sizeThatFits(NSSize(width: width, height: .greatestFiniteMagnitude)).height
        }
        var size = limitedSize
        size.height = height
        return size
    }

    override func dashboardViewControllerDidChange() {
        super.dashboardViewControllerDidChange()
        containerView.backgroundColorName = "DashboardCardValueBGColor"
    }

    // MARK: - NSMenuDelegate

    private func handleClick(_ event: NSEvent) {
        if !canEdit() {
            return
        }

        guard let menu = dashboardViewController?.currentDataSource()?.selectColorMenu else {
            return
        }
        menu.delegate = self
        NSMenu.popUpContextMenu(menu, with: event, for: containerView)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        for menuItem in menu.items {
            if menuItem.hasSubmenu {
                menuItem.submenu?.items.forEach { updateMenuItem($0) }
            } else {
                updateMenuItem(menuItem)
            }
        }
    }

    private func updateMenuItem(_ menuItem: NSMenuItem) {
        let dataSource = dashboardViewController?.currentDataSource()
        if menuItem.tag == dataSource?.customColorMenuItemTag {
            // "自定义颜色"
            menuItem.state = .off
            menuItem.onAction { [weak self] _ in
                self?.handleCustomColorMenuItem()
            }
            return
        }

        if menuItem.tag == dataSource?.toggleColorFormatMenuItemTag {
            menuItem.state = .off
            menuItem.onAction { _ in
                let isRGBA = LKPreferenceManager.mainManager.rgbaFormat
                LKPreferenceManager.mainManager.rgbaFormat = !isRGBA
            }
            return
        }
        menuItem.onAction { [weak self] item in
            self?.modify(toColor: item.representedObject as? NSColor)
        }
        let color = menuItem.representedObject as? NSColor
        let value = attribute?.value as? NSObject
        // 后面的判断是用来处理二者都是 nil 的情况
        if value?.isEqual(color?.rgbaComponents()) == true || (value == nil && color == nil) {
            menuItem.state = .on
        } else {
            menuItem.state = .off
        }
    }

    private func handleCustomColorMenuItem() {
        let initialColor = NSColor.color(fromRGBAComponents: attribute?.value as? [Any])

        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        panel.isContinuous = false
        if let initialColor {
            panel.color = initialColor
        }
        panel.setTarget(nil)
        panel.setAction(nil)
        let trampoline = LKActionTrampoline { [weak self] sender in
            if let panel = sender as? NSColorPanel {
                self?.modify(toColor: panel.color)
            }
        }
        panel.lookin_bindObject(trampoline, forKey: "lk_colorPanelTrampoline")
        panel.setTarget(trampoline)
        panel.setAction(#selector(LKActionTrampoline.performAction(_:)))
        panel.orderFront(self)
    }

    private func modify(toColor targetColor: NSColor?) {
        let expectedValue = targetColor?.rgbaComponents()
        if (attribute?.value as? NSObject)?.isEqual(expectedValue) == true {
            NSLog("修改没有变化，不做任何提交")
            return
        }
        // 提交修改
        guard let attribute, let dashboardViewController else { return }
        Task { [weak self] in
            if (try? await dashboardViewController.modifyAttribute(attribute, newValue: expectedValue)) != nil {
                self?.renderWithAttribute()
            }
        }
    }
}
