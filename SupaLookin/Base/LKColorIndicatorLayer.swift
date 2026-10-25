//
//  LKColorIndicatorLayer.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/1/19.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

// CALayer's initializers are nonisolated, so the layer is too; only the shared rendering helper below touches main-actor state.
nonisolated final class LKColorIndicatorLayer: CALayer {

    private var imageLayer: CALayer?
    private let colorLayer = CALayer()

    /// 默认为 (0, 0, 0)
    var color: NSColor? = NSColor(lookinRed: 0, green: 0, blue: 0) {
        didSet {
            if let color {
                if color.alphaComponent < 1 {
                    createImageLayerIfNeeded()
                    imageLayer?.isHidden = false
                    imageLayer?.contents = NSImage(named: "Transparent_Background")
                } else {
                    imageLayer?.isHidden = true
                }
            } else {
                createImageLayerIfNeeded()
                imageLayer?.isHidden = false
                imageLayer?.contents = NSImage(named: "Nil_Color_Image")
            }
            colorLayer.backgroundColor = color?.cgColor
            borderColor = contrastColor(for: color).cgColor
        }
    }

    override init() {
        super.init()
        lookin_removeImplicitAnimations()
        borderWidth = 1
        colorLayer.backgroundColor = color?.cgColor
        colorLayer.lookin_removeImplicitAnimations()
        addSublayer(colorLayer)
        masksToBounds = true
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func contrastColor(for color: NSColor?) -> NSColor {
        guard let color else {
            return NSColor(lookinRed: 191, green: 191, blue: 191)
        }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let newBrightness = brightness > 0.5 ? brightness - 0.2 : brightness + 0.2
        let newAlpha = min(1, alpha + 0.3)
        return NSColor(hue: hue, saturation: saturation, brightness: newBrightness, alpha: newAlpha)
    }

    private func createImageLayerIfNeeded() {
        if imageLayer != nil {
            return
        }
        let layer = CALayer()
        layer.lookin_removeImplicitAnimations()
        insertSublayer(layer, at: 0)
        imageLayer = layer
        setNeedsLayout()
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        // Same as fillSuperview, which is main-actor isolated
        for layer in [imageLayer, colorLayer].compactMap({ $0 }) where !layer.isHidden {
            layer.frame = bounds
        }
        cornerRadius = min(frame.width, frame.height) / 2.0
    }

    @MainActor private static var sharedLayer: LKColorIndicatorLayer?

    @MainActor static func image(with color: NSColor?, shapeSize: NSSize, insets: NSEdgeInsets) -> NSImage {
        let layer = sharedLayer ?? LKColorIndicatorLayer()
        sharedLayer = layer

        let image = NSImage(size: NSSize(width: shapeSize.width + insets.left + insets.right, height: shapeSize.height + insets.top + insets.bottom))
        image.lockFocus()
        layer.frame = NSRect(x: 0, y: 0, width: shapeSize.width, height: shapeSize.height)
        layer.color = color
        if let context = NSGraphicsContext.current?.cgContext {
            context.translateBy(x: insets.left, y: insets.top)
            layer.render(in: context)
        }
        image.unlockFocus()
        return image
    }
}
