//
//  SPLKMasksViewController.swift
//  SPLKChat
//
//  Created by Weirui Kong on 2026/11/25.
//

import UIKit

final class SPLKMasksViewController: UIViewController {

    private let toggleCase = SPLKToggleMaskCase()
    private let toggle = UISwitch()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Masks"
        view.backgroundColor = .systemGroupedBackground

        toggle.isOn = true
        toggle.accessibilityIdentifier = "masks.toggle"
        toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [
            card("maskView with subviews", SPLKMaskViewCase(), id: "masks.maskView"),
            card("layer.mask on an image view", SPLKShapeMaskCase(), id: "masks.shapeMask"),
            card("Gradient fade on a label", SPLKFadeMaskCase(), id: "masks.fade"),
            card("A mask with its own mask", SPLKNestedMaskCase(), id: "masks.nested"),
            card("Mask on", toggleCase, id: "masks.toggled", accessory: toggle),
        ])
        stack.axis = .vertical
        stack.spacing = 16

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "masks.list"
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
        ])
    }

    private func card(_ title: String, _ content: UIView, id: String, accessory: UIView? = nil) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        let header = UIStackView(arrangedSubviews: [label, accessory].compactMap { $0 })
        header.alignment = .center

        content.accessibilityIdentifier = id
        content.backgroundColor = .secondarySystemGroupedBackground
        content.layer.cornerRadius = 12
        content.heightAnchor.constraint(equalToConstant: 120).isActive = true

        let card = UIStackView(arrangedSubviews: [header, content])
        card.axis = .vertical
        card.spacing = 6
        return card
    }

    @objc private func toggleChanged(_ toggle: UISwitch) {
        toggleCase.isMasked = toggle.isOn
    }

    // For tests driving the app through SPLKServer's method invocation.
    @objc func toggleMask() {
        toggle.setOn(!toggle.isOn, animated: false)
        toggleChanged(toggle)
    }
}

final class SPLKGradientView: UIView {

    override class var layerClass: AnyClass { CAGradientLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let gradient = layer as! CAGradientLayer
        gradient.colors = [UIColor.systemPink.cgColor, UIColor.systemOrange.cgColor, UIColor.systemTeal.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// A maskView isn't laid out by its owner, so each case sets its mask's frame itself.
final class SPLKMaskViewCase: UIView {

    private let content = SPLKGradientView()
    private let shape = UIView()
    private let dot = UIView()
    private let bar = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        dot.backgroundColor = .black
        bar.backgroundColor = .black
        shape.addSubview(dot)
        shape.addSubview(bar)
        content.mask = shape
        addSubview(content)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        content.frame = bounds.insetBy(dx: 16, dy: 16)
        shape.frame = content.bounds
        let side = content.bounds.height
        dot.frame = CGRect(x: 0, y: 0, width: side, height: side)
        dot.layer.cornerRadius = side / 2
        bar.frame = CGRect(x: side + 12, y: side / 4, width: content.bounds.width - side - 12, height: side / 2)
        bar.layer.cornerRadius = side / 4
    }
}

final class SPLKShapeMaskCase: UIView {

    private let imageView = UIImageView(image: UIImage(systemName: "person.crop.square.fill"))
    private let star = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.tintColor = .systemIndigo
        imageView.layer.mask = star
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = bounds.height - 16
        imageView.frame = CGRect(x: (bounds.width - side) / 2, y: 8, width: side, height: side)
        star.frame = imageView.bounds
        star.path = Self.starPath(in: imageView.bounds)
    }

    private static func starPath(in rect: CGRect) -> CGPath {
        let path = UIBezierPath()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        for index in 0..<10 {
            let radius = index.isMultiple(of: 2) ? outer : outer * 0.45
            let angle = CGFloat(index) * .pi / 5 - .pi / 2
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.close()
        return path.cgPath
    }
}

final class SPLKFadeMaskCase: UIView {

    private let label = UILabel()
    private let fade = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.text = "A long line of text that fades out before it reaches the edge of the card, through a gradient mask."
        label.numberOfLines = 3
        label.font = .preferredFont(forTextStyle: .title3)
        fade.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        fade.locations = [0, 0.6, 1]
        fade.startPoint = CGPoint(x: 0, y: 0.5)
        fade.endPoint = CGPoint(x: 1, y: 0.5)
        label.layer.mask = fade
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 16, dy: 12)
        fade.frame = label.bounds
    }
}

final class SPLKNestedMaskCase: UIView {

    private let content = SPLKGradientView()
    private let outer = UIView()
    private let text = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        outer.backgroundColor = .black
        text.text = "MASKED"
        text.font = .systemFont(ofSize: 64, weight: .black)
        text.textAlignment = .center
        outer.mask = text
        content.mask = outer
        addSubview(content)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        content.frame = bounds.insetBy(dx: 16, dy: 16)
        outer.frame = content.bounds.insetBy(dx: 24, dy: 0)
        outer.layer.cornerRadius = 20
        text.frame = outer.bounds
    }
}

final class SPLKToggleMaskCase: UIView {

    var isMasked = true {
        didSet {
            content.mask = isMasked ? circle : nil
            setNeedsLayout()
        }
    }

    private let content = SPLKGradientView()
    private let circle = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        circle.backgroundColor = .black
        content.mask = circle
        addSubview(content)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        content.frame = bounds.insetBy(dx: 16, dy: 16)
        let side = content.bounds.height
        circle.frame = CGRect(x: (content.bounds.width - side) / 2, y: 0, width: side, height: side)
        circle.layer.cornerRadius = side / 2
    }
}
