//
//  LKDashboardAttributeShadowView.swift
//  SupaLookin
//
//  Created by likai.123 on 2023/11/29.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import LookinShared

final class LKDashboardAttributeShadowView: LKDashboardAttributeView {

    private let colorContainerView = LKBaseView()
    private let colorIndicatorLayer = LKColorIndicatorLayer()
    private let colorDescLabel = LKLabel()
    private var inputViews: [LKNumberInputView] = []

    private var cancellables = Set<AnyCancellable>()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        colorContainerView.layer?.cornerRadius = DashboardCardControlCornerRadius
        colorContainerView.backgroundColorName = "DashboardCardValueBGColor"
        addSubview(colorContainerView)

        colorContainerView.layer?.addSublayer(colorIndicatorLayer)

        colorDescLabel.textColor = NSColor(named: "DashboardCardValueColor")
        colorDescLabel.font = .systemFont(ofSize: 13)
        colorContainerView.addSubview(colorDescLabel)

        let titles = ["Opacity", "Radius", "OffsetW", "OffsetH"]
        inputViews = titles.map { title in
            let view = LKNumberInputView()
            view.textFieldView.textField.isEditable = false
            view.title = title
            view.viewStyle = .vertical
            addSubview(view)
            return view
        }

        LKPreferenceManager.mainManager.rgbaFormatPublisher
            .dropFirst()
            .sink { [weak self] _ in
                self?.renderWithAttribute()
            }
            .store(in: &cancellables)
    }

    override func layout() {
        super.layout()
        colorContainerView.fillWidth().setHeight(30).setY(0)
        colorIndicatorLayer.setWidth(16).setHeight(16).setX(8).centerVertically()
        colorDescLabel.setX(28).extendToRight(20).fitHeight().centerVertically().offset(y: -1)

        let itemWidth = (frame.width - DashboardAttrItemHorInterspace * 3) / 4.0
        let y = colorContainerView.frame.maxY + DashboardAttrItemVerInterspace
        var x: CGFloat = 0
        for view in inputViews {
            view.setWidth(itemWidth).setHeight(LKNumberInputVerticalHeight).setX(x).setY(y)
            x += itemWidth + DashboardAttrItemHorInterspace
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        size.height = 30 + DashboardAttrItemVerInterspace + LKNumberInputVerticalHeight
        return size
    }

    override func renderWithAttribute() {
        guard let attribute else {
            assertionFailure()
            return
        }
        guard let info = attribute.value as? [String: Any] else {
            assertionFailure()
            return
        }
        // 可能为 nil
        let color = NSColor.color(fromRGBAComponents: info["color"] as? [Any])

        guard let offsetValue = info["offset"] as? NSValue else {
            assertionFailure()
            return
        }
        let offset = offsetValue.sizeValue

        guard let opacityNumber = info["opacity"] as? NSNumber else {
            assertionFailure()
            return
        }
        let opacity = opacityNumber.doubleValue

        guard let radiusNumber = info["radius"] as? NSNumber else {
            assertionFailure()
            return
        }
        let radius = radiusNumber.doubleValue

        colorIndicatorLayer.color = color
        if let color {
            colorDescLabel.stringValue = LKPreferenceManager.mainManager.rgbaFormat ? color.rgbaString : color.hexString
        } else {
            colorDescLabel.stringValue = "nil"
        }

        let strs = [NSString.lookin_string(from: opacity, decimal: 2) ?? "",
                    NSString.lookin_string(from: radius, decimal: 2) ?? "",
                    NSString.lookin_string(from: offset.width, decimal: 2) ?? "",
                    NSString.lookin_string(from: offset.height, decimal: 2) ?? ""]
        for (idx, view) in inputViews.enumerated() {
            view.textFieldView.textField.stringValue = strs[idx]
        }
    }
}
