//
//  LKDashboardSearchPropView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/9/5.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

protocol LKDashboardSearchPropViewDelegate: AnyObject {
    func dashboardSearchPropView(_ view: LKDashboardSearchPropView, didClickRevealAttribute attr: LookinAttribute?)
}

final class LKDashboardSearchPropView: LKDashboardSearchCardView {

    weak var delegate: LKDashboardSearchPropViewDelegate?

    private let titleLabel = LKLabel()
    private let contentLabel = LKLabel()
    private let revealControl = LKTextControl()
    private var attribute: LookinAttribute?

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
        contentLabel.textColor = isDarkMode ? NSColor(lookinRed: 250, green: 251, blue: 252) : NSColor(lookinRed: 56, green: 57, blue: 58)

        let text = NSLocalizedString("Reveal in panel…", comment: "")
        let builder = LKAttributedStringBuilder(text)
        let colored = isDarkMode ? builder.textColor(red: 245, green: 166, blue: 30) : builder.textColor(red: 229, green: 135, blue: 67)
        revealControl.label.attributedStringValue = colored.font(size: 11).addImage(named: "icon_arrowRight_orange", baselineOffset: 0, marginLeft: 2, marginRight: 0).attributedString ?? NSAttributedString()
    }

    func render(withAttribute attribute: LookinAttribute) {
        self.attribute = attribute
        titleLabel.stringValue = attribute.displayTitle ?? LookinDashboardBlueprint.fullTitle(withAttrID: attribute.identifier) ?? ""
        contentLabel.stringValue = stringValue(from: attribute)
        needsLayout = true
    }

    private func stringValue(from attribute: LookinAttribute) -> String {
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
            return NSString.lookin_string(from: (attribute.value as? NSValue)?.pointValue ?? .zero)
        case .cgSize:
            return NSString.lookin_string(from: (attribute.value as? NSValue)?.sizeValue ?? .zero)
        case .cgRect:
            return NSString.lookin_string(from: (attribute.value as? NSValue)?.rectValue ?? .zero)
        case .uiEdgeInsets:
            return NSString.lookin_string(fromInset: (attribute.value as? NSValue)?.edgeInsetsValue ?? NSEdgeInsets())

        case .nsString, .enumString:
            return attribute.value as? String ?? ""

        case .enumInt, .enumLong:
            let enumValue = (attribute.value as? NSNumber)?.intValue ?? 0
            let enumListName = LookinDashboardBlueprint.enumListName(withAttrID: attribute.identifier) ?? ""
            return LKEnumListRegistry.sharedInstance.desc(forEnumName: enumListName, value: enumValue) ?? ""

        case .uiColor:
            if let color = NSColor.color(fromRGBAComponents: attribute.value as? [Any]) {
                return LKPreferenceManager.mainManager.rgbaFormat ? color.rgbaString : color.hexString
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
