//
//  SPLKChatsViewController.swift
//  SPLKChat
//
//  Created by Weirui Kong on 2026/11/18.
//

import UIKit

final class SPLKChatsViewController: UITableViewController {

    private let store = SPLKChatStore.shared

    init() {
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(SPLKChatListCell.self, forCellReuseIdentifier: SPLKChatListCell.reuseIdentifier)
        tableView.rowHeight = 72
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 76, bottom: 0, right: 0)
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "plus.circle"), style: .plain, target: self, action: #selector(showMoreActions(_:)))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "chats.more"
        NotificationCenter.default.addObserver(self, selector: #selector(storeDidChange), name: SPLKChatStore.didChangeNotification, object: store)
        updateBadge()
    }

    @objc private func storeDidChange() {
        tableView.reloadData()
        updateBadge()
    }

    private func updateBadge() {
        let unread = store.totalUnread
        navigationController?.tabBarItem.badgeValue = unread > 0 ? String(unread) : nil
        title = unread > 0 ? "Chats (\(unread))" : "Chats"
        navigationController?.tabBarItem.title = "Chats"
    }

    @objc private func showMoreActions(_ sender: UIBarButtonItem) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "New Chat", style: .default) { [weak self] _ in
            self?.tabBarController?.selectedIndex = 1
        })
        sheet.addAction(UIAlertAction(title: "Mark All as Read", style: .default) { [weak self] _ in
            self?.store.conversations.forEach { self?.store.markRead($0) }
        })
        sheet.addAction(UIAlertAction(title: "Simulate Incoming Message", style: .default) { [weak self] _ in
            guard let self, let conversation = store.conversations.randomElement() else { return }
            store.receive("Ping at \(SPLKChatFormat.listDate(Date()))", in: conversation, read: false)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = sender
        present(sheet, animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        store.conversations.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SPLKChatListCell.reuseIdentifier, for: indexPath) as! SPLKChatListCell
        cell.configure(with: store.conversations[indexPath.row])
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let conversation = SPLKConversationViewController(conversation: store.conversations[indexPath.row])
        conversation.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(conversation, animated: true)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let conversation = store.conversations[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            self?.store.delete(conversation)
            done(true)
        }
        let mute = UIContextualAction(style: .normal, title: conversation.isMuted ? "Unmute" : "Mute") { [weak self] _, _, done in
            conversation.isMuted.toggle()
            self?.storeDidChange()
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete, mute])
    }
}

final class SPLKChatListCell: UITableViewCell {

    static let reuseIdentifier = "SPLKChatListCell"

    private let avatar = SPLKAvatarView(size: 48)
    private let nameLabel = UILabel()
    private let previewLabel = UILabel()
    private let dateLabel = UILabel()
    private let badgeLabel = SPLKBadgeLabel()
    private let muteIcon = UIImageView(image: UIImage(systemName: "bell.slash"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        nameLabel.font = .systemFont(ofSize: 17)
        previewLabel.font = .systemFont(ofSize: 14)
        previewLabel.textColor = .secondaryLabel
        dateLabel.font = .systemFont(ofSize: 12)
        dateLabel.textColor = .tertiaryLabel
        dateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        dateLabel.setContentHuggingPriority(.required, for: .horizontal)
        muteIcon.tintColor = .tertiaryLabel
        muteIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12)

        let topRow = UIStackView(arrangedSubviews: [nameLabel, dateLabel])
        let bottomRow = UIStackView(arrangedSubviews: [previewLabel, muteIcon])
        bottomRow.spacing = 4
        let text = UIStackView(arrangedSubviews: [topRow, bottomRow])
        text.axis = .vertical
        text.spacing = 4
        text.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(avatar)
        contentView.addSubview(text)
        contentView.addSubview(badgeLabel)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatar.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            text.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            text.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            text.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            badgeLabel.centerXAnchor.constraint(equalTo: avatar.trailingAnchor, constant: -2),
            badgeLabel.centerYAnchor.constraint(equalTo: avatar.topAnchor, constant: 2),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with conversation: SPLKChatConversation) {
        avatar.configure(with: conversation.contact)
        nameLabel.text = conversation.contact.name
        previewLabel.text = conversation.messages.last?.text ?? " "
        dateLabel.text = conversation.messages.last.map { SPLKChatFormat.listDate($0.date) }
        badgeLabel.count = conversation.unreadCount
        muteIcon.isHidden = !conversation.isMuted
        accessibilityIdentifier = "chats.row.\(conversation.contact.id)"
    }
}

final class SPLKBadgeLabel: UILabel {

    var count = 0 {
        didSet {
            text = String(count)
            isHidden = count == 0
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemRed
        textColor = .white
        font = .systemFont(ofSize: 12, weight: .semibold)
        textAlignment = .center
        layer.cornerRadius = 9
        clipsToBounds = true
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: max(18, size.width + 10), height: 18)
    }
}
