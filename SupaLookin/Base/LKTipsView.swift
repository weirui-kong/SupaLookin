//
//  LKTipsView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/8.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

class LKTipsView: LKBaseView {

    weak var bindingObject: AnyObject?

    fileprivate let titleLabel = LKLabel()
    private let imageView = NSImageView()
    fileprivate let sepLayer = CALayer()

    /// 请外部不要直接修改 button 的 text 等属性，而是要通过下面的 buttonText 和 buttonImage 来设置
    private(set) var button: NSButton!

    private var insetLeft: CGFloat = 12
    private var insetRightWithButton: CGFloat = 3
    private var insetRightWithoutButton: CGFloat = 8
    private var imageRight: CGFloat = 4
    private var sepLeft: CGFloat = 7
    private var imageSize = NSSize(width: 18, height: 18)

    var title: String? {
        didSet {
            titleLabel.stringValue = title ?? ""
        }
    }

    /// buttonText 和 buttonImage 只有一个会生效，请勿同时设置
    var buttonText: String? {
        didSet {
            updateButton()
        }
    }

    var buttonImage: NSImage? {
        didSet {
            updateButton()
        }
    }

    var image: NSImage? {
        didSet {
            imageView.image = image
            imageView.isHidden = image == nil
        }
    }

    var clickAction: ((LKTipsView) -> Void)?

    var didClick: ((LKTipsView) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.borderWidth = 1

        imageView.isHidden = true
        addSubview(imageView)

        titleLabel.font = .systemFont(ofSize: 13)
        addSubview(titleLabel)

        let button = NSButton()
        button.font = .systemFont(ofSize: 13)
        button.isBordered = false
        button.bezelStyle = .smallSquare
        button.onAction { [weak self] _ in
            self?.handleButton()
        }
        button.isHidden = true
        addSubview(button)
        self.button = button

        sepLayer.lookin_removeImplicitAnimations()
        sepLayer.isHidden = true
        layer?.addSublayer(sepLayer)

        updateColors()
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = frame.height / 2.0
        var x = insetLeft
        if !imageView.isHidden {
            imageView.setSize(imageSize).centerVertically().setX(x)
            x = imageView.frame.maxX + imageRight
        }

        titleLabel.fitSize().centerVertically().setX(x)
        x = titleLabel.frame.maxX

        if !sepLayer.isHidden {
            sepLayer.setWidth(1).fillHeight().setX(x + sepLeft)
            x = sepLayer.frame.maxX
        }

        if !button.isHidden {
            button.setX(x).extendToRight(insetRightWithButton).fillHeight()
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        let height: CGFloat = 28

        var width = insetLeft
        if !imageView.isHidden {
            width += imageSize.width + imageRight
        }

        width += titleLabel.sizeThatFits(.max).width

        if !sepLayer.isHidden {
            width += sepLeft + 1
        }

        if !button.isHidden {
            width += button.sizeThatFits(.max).width + 16
        } else {
            width += insetRightWithoutButton
        }

        return NSSize(width: width, height: height)
    }

    override func updateColors() {
        super.updateColors()
        backgroundColor = isDarkMode ? NSColor(lookinRed: 0, green: 0, blue: 0, alpha: 0.8) : NSColor(lookinRed: 255, green: 255, blue: 255, alpha: 0.9)
        titleLabel.textColor = isDarkMode ? NSColor(lookinRed: 197, green: 198, blue: 199) : NSColor(lookinRed: 108, green: 109, blue: 110)

        let borderColor = isDarkMode ? NSColor(lookinRed: 43, green: 44, blue: 45) : NSColor(lookinRed: 216, green: 217, blue: 218)
        layer?.borderColor = borderColor.cgColor
        sepLayer.backgroundColor = borderColor.cgColor
        updateButton()
    }

    func setImage(byDeviceType type: LookinAppInfoDevice) {
        switch type.rawValue {
        case 0:
            image = NSImage(named: "icon_simulator_big")
        case 1:
            image = NSImage(named: "icon_ipad_big")
        case 2:
            image = NSImage(named: "icon_iphone_big")
        default:
            assertionFailure()
        }
    }

    func setInternalInsetsRight(_ value: CGFloat) {
        insetRightWithButton = value
        insetRightWithoutButton = value
        imageRight = value
    }

    private func handleButton() {
        clickAction?(self)
        didClick?(self)
    }

    private func updateButton() {
        // updateColors() runs from LKBaseView's init, before the button exists.
        guard let button else {
            return
        }
        button.isHidden = false
        sepLayer.isHidden = false

        if let buttonText {
            button.attributedTitle = LKAttributedStringBuilder(buttonText).textColor(buttonTextColor).attributedString ?? NSAttributedString()
            button.image = nil
        } else if let buttonImage {
            button.title = ""
            button.image = buttonImage
        } else {
            button.isHidden = true
            sepLayer.isHidden = true
        }
        needsLayout = true
    }

    var buttonTextColor: NSColor {
        isDarkMode ? NSColor(lookinRed: 64, green: 134, blue: 216) : NSColor(lookinRed: 74, green: 145, blue: 228)
    }
}

final class LKYellowTipsView: LKTipsView {

    private var isAnimating = false

    func startAnimation() {
        if isAnimating {
            return
        }
        let anim = CABasicAnimation(keyPath: "backgroundColor")
        if effectiveAppearance.isDarkMode {
            anim.fromValue = NSColor.systemOrange.withAlphaComponent(0.7).cgColor
            anim.toValue = NSColor.systemOrange.withAlphaComponent(0.64).cgColor
        } else {
            anim.fromValue = NSColor.systemOrange.withAlphaComponent(0.98).cgColor
            anim.toValue = NSColor.systemOrange.withAlphaComponent(0.92).cgColor
        }
        anim.duration = 0.8
        anim.repeatCount = .greatestFiniteMagnitude
        anim.autoreverses = true
        layer?.removeAllAnimations()
        layer?.add(anim, forKey: nil)

        isAnimating = true
    }

    func endAnimation() {
        layer?.removeAllAnimations()
        isAnimating = false
    }

    override func updateColors() {
        super.updateColors()
        titleLabel.textColor = .white
        layer?.borderColor = NSColor.clear.cgColor
        sepLayer.backgroundColor = NSColor(lookinRed: 255, green: 255, blue: 255, alpha: 0.5).cgColor
    }

    override var buttonTextColor: NSColor {
        .white
    }
}

final class LKRedTipsView: LKTipsView {

    func startAnimation() {
        let anim = CABasicAnimation(keyPath: "backgroundColor")
        anim.fromValue = NSColor(lookinRed: 208, green: 2, blue: 27, alpha: 0.9).cgColor
        anim.toValue = NSColor(lookinRed: 208, green: 2, blue: 27, alpha: 0.7).cgColor
        anim.duration = 0.8
        anim.repeatCount = .greatestFiniteMagnitude
        anim.autoreverses = true
        layer?.removeAllAnimations()
        layer?.add(anim, forKey: nil)
    }

    func endAnimation() {
        layer?.removeAllAnimations()
    }

    override func updateColors() {
        super.updateColors()
        titleLabel.textColor = .white
        layer?.borderColor = NSColor.clear.cgColor
        sepLayer.backgroundColor = NSColor(lookinRed: 255, green: 255, blue: 255, alpha: 0.5).cgColor
    }

    override var buttonTextColor: NSColor {
        .white
    }
}
