//
//  LKDashboardAttributeEnumsView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/2/21.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKDashboardAttributeEnumsView: LKDashboardAttributeView {

    private let iconImageView = NSImageView()
    private let textLabel = LKLabel()

    private let labelX: CGFloat = 5
    private let labelRight: CGFloat = 20

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.cornerRadius = DashboardCardControlCornerRadius

        textLabel.textColor = NSColor(named: "DashboardCardValueColor")
        textLabel.maximumNumberOfLines = 0
        textLabel.font = .systemFont(ofSize: 12)
        addSubview(textLabel)

        iconImageView.image = NSImage(named: "Icon_ArrowUpDown")
        addSubview(iconImageView)
    }

    override func layout() {
        super.layout()
        iconImageView.fitSize().centerVertically().alignRight(9)
        textLabel.setX(labelX).extendToRight(labelRight).fitHeight().centerVertically()
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        let height = textLabel.sizeThatFits(NSSize(width: limitedSize.width - labelRight - labelX, height: .greatestFiniteMagnitude)).height
        var size = limitedSize
        size.height = height + 10
        return size
    }

    override func renderWithAttribute() {
        guard let attribute else { return }
        if attribute.attrType == .enumString {
            guard let text = attribute.value as? String else {
                assertionFailure()
                return
            }
            textLabel.stringValue = text

        } else {
            let enumValue = (attribute.value as? NSNumber)?.intValue ?? 0
            let enumListName = LookinDashboardBlueprint.enumListName(withAttrID: attribute.identifier) ?? ""
            textLabel.stringValue = LKEnumListRegistry.sharedInstance.desc(forEnumName: enumListName, value: enumValue) ?? ""
        }
    }

    override func mouseDown(with event: NSEvent) {
        let menu: NSMenu
        if attribute?.isUserCustom() == true {
            menu = createMenuForUserCustom()
        } else {
            menu = createMenuForPreset()
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func dashboardViewControllerDidChange() {
        super.dashboardViewControllerDidChange()
        backgroundColorName = "DashboardCardValueBGColor"
    }

    // MARK: - Private

    private func createMenuForPreset() -> NSMenu {
        let currentOSVersion = Int(dashboardViewController?.currentDataSource()?.rawHierarchyInfo?.appInfo?.osMainVersion ?? 0)

        let menu = NSMenu()
        menu.autoenablesItems = false
        let enumListName = LookinDashboardBlueprint.enumListName(withAttrID: attribute?.identifier ?? "") ?? ""
        let rawItems = LKEnumListRegistry.sharedInstance.items(forEnumName: enumListName) ?? []
        let currentValue = (attribute?.value as? NSNumber)?.intValue
        for obj in rawItems {
            let validOSVersion = currentOSVersion >= obj.availableOSVersion

            let item = NSMenuItem()
            item.image = NSImage(size: NSSize(width: 1, height: 22))
            item.title = validOSVersion ? obj.desc : "\(obj.desc) (iOS \(obj.availableOSVersion))"
            item.representedObject = NSNumber(value: obj.value)
            item.isEnabled = canEdit() && validOSVersion
            item.onAction { [weak self] item in
                self?.handleMenuItem(item)
            }
            item.state = obj.value == currentValue ? .on : .off
            menu.addItem(item)
        }

        return menu
    }

    private func createMenuForUserCustom() -> NSMenu {
        let menu = NSMenu()

        guard let cases = attribute?.extraValue as? [Any], !cases.isEmpty else {
            return menu
        }

        for element in cases {
            guard let text = element as? String else {
                assertionFailure()
                continue
            }
            let item = NSMenuItem()
            item.image = NSImage(size: NSSize(width: 1, height: 22))
            item.title = text
            item.representedObject = text
            item.isEnabled = canEdit()
            item.onAction { [weak self] item in
                self?.handleMenuItem(item)
            }
            item.state = (text as NSString).isEqual(to: attribute?.value) ? .on : .off
            menu.addItem(item)
        }

        return menu
    }

    private func handleMenuItem(_ item: NSMenuItem) {
        let expectedValue = item.representedObject as? NSObject
        if expectedValue?.isEqual(attribute?.value) == true {
            NSLog("修改没有变化，不做任何提交")
            return
        }
        guard let attribute, let dashboardViewController else { return }
        Task { [weak self] in
            if (try? await dashboardViewController.modifyAttribute(attribute, newValue: expectedValue)) != nil {
                self?.renderWithAttribute()
            }
        }
    }
}
