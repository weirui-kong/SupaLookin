//
//  SPLKDashboardSearchPropView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/9/5.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import SPLKServer

protocol SPLKDashboardSearchPropViewDelegate: AnyObject {
    func dashboardSearchPropView(_ view: SPLKDashboardSearchPropView, didClickRevealAttribute attr: SPLKAttribute?)
}

final class SPLKDashboardSearchPropView: SPLKDashboardSearchCardView {

    weak var delegate: SPLKDashboardSearchPropViewDelegate?

    private let titleLabel = SPLKLabel()
    private let contentLabel = SPLKLabel()
    private let revealControl = SPLKTextControl()
    private var attribute: SPLKAttribute?

    private let contentLabelY: CGFloat = 21

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabelColor
        addSubview(titleLabel)

        contentLabel.font = .systemFont(ofSize: 15)
        addSubview(contentLabel)

        revealControl.clickAction = { [unowned self] _ in
            self.delegate?.dashboardSearchPropView(self, didClickRevealAttribute: self.attribute)
        }
        revealControl.adjustAlphaWhenClick = true
        addSubview(revealControl)

        updateColors()
    }

    override func layout() {
        super.layout()

        let width = frame.width - DashboardSearchCardInset * 2

        titleLabel.setX(DashboardSearchCardInset).setWidth(width).fitHeight().setY(5)
        contentLabel.setX(DashboardSearchCardInset).setWidth(width).fitHeight().setY(contentLabelY)
        revealControl.fitSize().setX(DashboardSearchCardInset).alignBottom(DashboardSearchCardInset)
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        let width = limitedSize.width - DashboardSearchCardInset * 2
        var height = contentLabelY
        height += contentLabel.height(forWidth: width) + DashboardSearchCardInset + 25
        var size = limitedSize
        size.height = height
        return size
    }

    override func updateColors() {
        super.updateColors()
        contentLabel.textColor = isDarkMode ? NSColor(splkRed: 250, green: 251, blue: 252) : NSColor(splkRed: 56, green: 57, blue: 58)

        let text = NSLocalizedString("Reveal in panel…", comment: "")
        let builder = SPLKAttributedStringBuilder(text)
        let colored = isDarkMode ? builder.textColor(red: 245, green: 166, blue: 30) : builder.textColor(red: 229, green: 135, blue: 67)
        revealControl.label.attributedStringValue = colored.font(size: 11).addImage(named: "icon_arrowRight_orange", baselineOffset: 0, marginLeft: 2, marginRight: 0).attributedString ?? NSAttributedString()
    }

    func render(withAttribute attribute: SPLKAttribute) {
        self.attribute = attribute
        titleLabel.stringValue = attribute.displayTitle ?? SPLKDashboardBlueprint.fullTitle(withAttrID: attribute.identifier) ?? ""
        contentLabel.stringValue = stringValue(from: attribute)
        needsLayout = true
    }

    private func stringValue(from attribute: SPLKAttribute) -> String {
        switch attribute.attrType {
        case .none, .void, .customObj:
            assertionFailure()
            return ""

        case .char, .int, .short, .long, .longLong, .unsignedChar, .unsignedInt, .unsignedShort, .unsignedLong, .unsignedLongLong, .float, .double, .sel, .class, .cgVector, .cgAffineTransform, .uiOffset:
            return (attribute.value as AnyObject?)?.description ?? "(null)"

        case .BOOL:
            let boolValue = (attribute.value as? NSNumber)?.boolValue ?? false
            return boolValue ? "YES" : "NO"

        case .cgPoint:
            return NSString.splk_string(from: (attribute.value as? NSValue)?.pointValue ?? .zero)
        case .cgSize:
            return NSString.splk_string(from: (attribute.value as? NSValue)?.sizeValue ?? .zero)
        case .cgRect:
            return NSString.splk_string(from: (attribute.value as? NSValue)?.rectValue ?? .zero)
        case .uiEdgeInsets:
            return NSString.splk_string(fromInset: (attribute.value as? NSValue)?.edgeInsetsValue ?? NSEdgeInsets())

        case .nsString, .enumString:
            return attribute.value as? String ?? ""

        case .enumInt, .enumLong:
            let enumValue = (attribute.value as? NSNumber)?.intValue ?? 0
            let enumListName = SPLKDashboardBlueprint.enumListName(withAttrID: attribute.identifier) ?? ""
            return SPLKEnumListRegistry.sharedInstance.desc(forEnumName: enumListName, value: enumValue) ?? ""

        case .uiColor:
            if let color = NSColor.color(fromRGBAComponents: attribute.value as? [Any]) {
                return SPLKPreferenceManager.mainManager.rgbaFormat ? color.rgbaString : color.hexString
            } else {
                return "nil"
            }

        case .shadow, .json:
            return "……"

        @unknown default:
            assertionFailure()
            return ""
        }
    }
}
