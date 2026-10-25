//
//  LKBaseView.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/8/4.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

enum LKViewBorderPosition {
    case none
    case top
    case left
    case bottom
    case right
}

class LKBaseView: NSView, NSViewToolTipOwner {

    private var customBorderLayer: CALayer?
    private var backgroundEffectView: LKVisualEffectView?

    var tooltipString: String? {
        didSet {
            if tooltipString != nil {
                addToolTip(bounds, owner: self, userData: nil)
            } else {
                removeAllToolTips()
            }
        }
    }

    var backgroundColor: NSColor? {
        didSet {
            layer?.backgroundColor = backgroundColor?.cgColor
        }
    }

    var backgroundColors: LKTwoColors? {
        didSet {
            updateColors()
        }
    }

    /// 可以单独设置某一条边有 border，颜色由 borderColors 属性决定，注意通过这个属性设置了单边 border 后，就不要再使用系统的 layer.border 接口来设置四边 border 了
    /// 默认为 none
    var borderPosition: LKViewBorderPosition = .none {
        didSet {
            if borderPosition == .none {
                customBorderLayer?.removeFromSuperlayer()
                return
            }
            if customBorderLayer == nil {
                let borderLayer = CALayer()
                borderLayer.lookin_removeImplicitAnimations()
                customBorderLayer = borderLayer
                updateColors()
                layer?.addSublayer(borderLayer)
            }
            needsLayout = true
        }
    }

    /// 通过系统的 layer.border 接口和上面的 borderPosition 接口设置的 border 均可被该属性影响到
    /// 默认为 separatorLightModeColor / separatorDarkModeColor
    var borderColors: LKTwoColors? {
        didSet {
            updateColors()
        }
    }

    /// 当设置该 block 之后，该 block 会立即被调用一次
    var didChangeAppearanceBlock: ((LKBaseView, Bool) -> Void)? {
        didSet {
            triggerDidChangeAppearanceBlock()
        }
    }

    var didLayout: (() -> Void)?

    /// 是否磨砂背景
    var hasEffectedBackground = false {
        didSet {
            if hasEffectedBackground {
                if backgroundEffectView != nil {
                    return
                }
                let effectView = LKVisualEffectView()
                effectView.blendingMode = .withinWindow
                effectView.state = .active
                backgroundEffectView = effectView
                insertSubviewAtBottom(effectView)
                needsLayout = true
            } else {
                backgroundEffectView?.removeFromSuperview()
                backgroundEffectView = nil
            }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        borderColors = LKTwoColors(lightMode: .separatorLightModeColor, darkMode: .separatorDarkModeColor)
        // didSet doesn't fire inside the declaring class's own init
        updateColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if isHidden || alphaValue <= 0 {
            return nil
        }
        return super.hitTest(point)
    }

    override func layout() {
        super.layout()

        backgroundEffectView?.fillSuperview()

        if tooltipString != nil {
            addToolTip(bounds, owner: self, userData: nil)
        } else {
            removeAllToolTips()
        }

        if let customBorderLayer {
            switch borderPosition {
            case .none:
                break
            case .top:
                customBorderLayer.fillWidth().setHeight(1).setY(0)
            case .left:
                customBorderLayer.fillHeight().setWidth(1).setX(0)
            case .bottom:
                customBorderLayer.fillSuperview().setHeight(1).alignBottom(0)
            case .right:
                customBorderLayer.fillHeight().setWidth(1).alignRight(0)
            }
        }

        didLayout?()
    }

    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        tooltipString ?? ""
    }

    func height(forWidth width: CGFloat) -> CGFloat {
        sizeThatFits(NSSize(width: width, height: .greatestFiniteMagnitude)).height
    }

    override func updateLayer() {
        super.updateLayer()
        if let backgroundColorName {
            layer?.backgroundColor = NSColor(named: backgroundColorName)?.cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        triggerDidChangeAppearanceBlock()
    }

    private func triggerDidChangeAppearanceBlock() {
        didChangeAppearanceBlock?(self, isDarkMode)
        updateColors()
    }

    /// 用户切换主题时，该方法会被调用，子类重写时须调用 super
    func updateColors() {
        if let backgroundColors {
            layer?.backgroundColor = backgroundColors.color.cgColor
        }
        if let borderColors {
            layer?.borderColor = borderColors.color.cgColor
            customBorderLayer?.backgroundColor = borderColors.color.cgColor
        }
    }

    var isDarkMode: Bool {
        effectiveAppearance.isDarkMode
    }

    // MARK: - Subclassing hooks

    func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        .zero
    }

    func sizeToFit() {
    }
}

final class LKVisualEffectView: NSVisualEffectView {

    override var isFlipped: Bool {
        true
    }
}
