//
//  LKDashboardAttributeStringArrayView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/15.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

class LKDashboardAttributeStringArrayView: LKDashboardAttributeView {

    private var labels: [LKLabel] = []
    private var sepLayers: [CALayer] = []
    private var danceButton: NSButton?

    private let labelsVerInterSpace: CGFloat = 10

    override func layout() {
        super.layout()
        for (idx, label) in labels.enumerated() {
            let prevLabel = idx > 0 ? labels[idx - 1] : nil
            label.fillSuperview().fitHeight().setY(prevLabel.map { $0.frame.maxY + labelsVerInterSpace } ?? 0)

            if idx > 0 {
                if let sepLayer = sepLayers.element(at: idx - 1) {
                    sepLayer.fillSuperview().setHeight(1).setY(label.frame.minY - labelsVerInterSpace / 2.0 + 1)
                } else {
                    assertionFailure()
                }
            }
        }
        if let danceButton, danceButton.isVisible {
            danceButton.setWidth(150).centerHorizontally().setHeight(25).alignBottom(0)
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        size.height = labels.enumerated().reduce(0) { accumulator, element in
            let (idx, label) = element
            var result = accumulator + label.sizeThatFits(limitedSize).height
            if idx > 0 {
                result += labelsVerInterSpace
            }
            return result
        }
        if let danceButton, danceButton.isVisible {
            size.height += 35
        }
        return size
    }

    func stringList(withAttribute attribute: LookinAttribute?) -> [String] {
        assertionFailure("should implement by subclass")
        return []
    }

    override func renderWithAttribute() {
        let lists = stringList(withAttribute: attribute)
        labels = labels.resized(count: lists.count, add: { _ in
            let label = LKLabel()
            label.lineBreakStrategy = []
            label.isSelectable = true
            label.allowsEditingTextAttributes = true
            self.addSubview(label)
            return label
        }, remove: { _, label in
            label.removeFromSuperview()
        }, doNext: { idx, label in
            let string = lists[idx]
            label.attributedStringValue = LKAttributedStringBuilder(string).textColor(.labelColor).font(.systemFont(ofSize: 12)).lineHeight(18).attributedString ?? NSAttributedString()
        })

        if lists.count > 1 {
            sepLayers = sepLayers.resized(count: lists.count - 1, add: { _ in
                let layer = CALayer()
                layer.lookin_removeImplicitAnimations()
                self.layer?.addSublayer(layer)
                return layer
            }, remove: { _, layer in
                layer.removeFromSuperlayer()
            }, doNext: { _, _ in
            })
            updateColors()

        } else {
            sepLayers.forEach { $0.removeFromSuperlayer() }
            sepLayers = []
        }

        danceButton?.isHidden = true
        if attribute?.identifier == LookinAttr_Class_Class_Class {
            let danceSource = attribute?.targetDisplayItem?.danceuiSource ?? attribute?.targetDisplayItem?.customInfo?.danceuiSource
            if danceSource != nil {
                let button = addDanceButtonIfNeeded()
                button.title = NSLocalizedString("Navigate…", comment: "")
                button.isHidden = false
            }
        }

        needsLayout = true
    }

    override func updateColors() {
        super.updateColors()
        for layer in sepLayers {
            layer.backgroundColor = isDarkMode ? NSColor.separatorDarkModeColor.cgColor : NSColor.separatorLightModeColor.cgColor
        }
    }

    private func addDanceButtonIfNeeded() -> NSButton {
        if let danceButton {
            return danceButton
        }
        let button = NSButton.normalButton(title: "") { [unowned self] _ in
            self.handleDanceButton()
        }
        button.font = .systemFont(ofSize: 12)
        addSubview(button)
        danceButton = button
        return button
    }

    private func handleDanceButton() {
        let json = attribute?.targetDisplayItem?.danceuiSource ?? attribute?.targetDisplayItem?.customInfo?.danceuiSource
        DanceScriptManager.shared.handleText(json)
    }
}
