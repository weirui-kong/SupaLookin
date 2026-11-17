//
//  SPLKAvatarView.swift
//  SPLKChat
//
//  Created by Weirui Kong on 2026/11/18.
//

import UIKit

final class SPLKAvatarView: UIView {

    private let label = UILabel()
    private let size: CGFloat

    init(size: CGFloat) {
        self.size = size
        super.init(frame: .zero)
        layer.cornerRadius = size * 0.18
        layer.cornerCurve = .continuous
        clipsToBounds = true
        label.textColor = .white
        label.font = .systemFont(ofSize: size * 0.38, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with contact: SPLKChatContact) {
        backgroundColor = contact.color
        label.text = contact.initials
        accessibilityLabel = contact.name
    }
}
