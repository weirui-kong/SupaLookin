//
//  SPLKConversationViewController.swift
//  SPLKChat
//
//  Created by Weirui Kong on 2026/11/18.
//

import UIKit

final class SPLKConversationViewController: UIViewController, UITableViewDataSource, UITextFieldDelegate {

    private let conversation: SPLKChatConversation
    private let store = SPLKChatStore.shared
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputBar = UIView()
    private let textField = UITextField()
    private let sendButton = UIButton(type: .system)

    init(conversation: SPLKChatConversation) {
        self.conversation = conversation
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = conversation.contact.name
        view.backgroundColor = .splkChatBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: self, action: #selector(showDetails(_:)))

        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.keyboardDismissMode = .interactive
        tableView.register(SPLKMessageCell.self, forCellReuseIdentifier: SPLKMessageCell.reuseIdentifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.accessibilityIdentifier = "conversation.messages"
        view.addSubview(tableView)

        inputBar.backgroundColor = .secondarySystemBackground
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputBar)

        textField.placeholder = "Message"
        textField.borderStyle = .roundedRect
        textField.returnKeyType = .send
        textField.enablesReturnKeyAutomatically = true
        textField.delegate = self
        textField.accessibilityIdentifier = "conversation.input"
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)

        sendButton.setTitle("Send", for: .normal)
        sendButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        sendButton.isEnabled = false
        sendButton.accessibilityIdentifier = "conversation.send"
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [textField, sendButton])
        row.spacing = 10
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        inputBar.addSubview(row)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputBar.topAnchor),
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            row.topAnchor.constraint(equalTo: inputBar.topAnchor, constant: 8),
            row.leadingAnchor.constraint(equalTo: inputBar.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: inputBar.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            // The keyboard layout guide follows the safe area while the keyboard is hidden.
            row.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8),
            textField.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        store.markRead(conversation)
        scrollToBottom(animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !tableView.isTracking, textField.isFirstResponder {
            scrollToBottom(animated: false)
        }
    }

    @objc private func textChanged() {
        sendButton.isEnabled = !(textField.text ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    @objc private func sendTapped() {
        send()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        send()
        return false
    }

    private func send() {
        let text = (textField.text ?? "").trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        textField.text = nil
        textChanged()
        store.send(text, in: conversation)
        appendRow()
        scheduleReply(to: text)
    }

    private func scheduleReply(to text: String) {
        let name = conversation.contact.name
        title = "Typing…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }
            title = name
            store.receive(store.autoReply(to: text), in: conversation, read: navigationController?.topViewController === self)
            appendRow()
        }
    }

    private func appendRow() {
        tableView.insertRows(at: [IndexPath(row: conversation.messages.count - 1, section: 0)], with: .bottom)
        scrollToBottom(animated: true)
    }

    private func scrollToBottom(animated: Bool) {
        guard !conversation.messages.isEmpty else { return }
        tableView.scrollToRow(at: IndexPath(row: conversation.messages.count - 1, section: 0), at: .bottom, animated: animated)
    }

    @objc private func showDetails(_ sender: UIBarButtonItem) {
        let sheet = UIAlertController(title: conversation.contact.name, message: conversation.contact.status, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: conversation.isMuted ? "Unmute" : "Mute Notifications", style: .default) { [weak self] _ in
            self?.conversation.isMuted.toggle()
        })
        sheet.addAction(UIAlertAction(title: "Clear Chat History", style: .destructive) { [weak self] _ in
            guard let self else { return }
            store.clearHistory(of: conversation)
            tableView.reloadData()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = sender
        present(sheet, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        conversation.messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SPLKMessageCell.reuseIdentifier, for: indexPath) as! SPLKMessageCell
        let message = conversation.messages[indexPath.row]
        cell.configure(with: message, sender: message.isOutgoing ? store.me : conversation.contact)
        return cell
    }
}

final class SPLKMessageCell: UITableViewCell {

    static let reuseIdentifier = "SPLKMessageCell"

    private let avatar = SPLKAvatarView(size: 40)
    private let bubble = UIView()
    private let messageLabel = UILabel()
    private var incomingConstraints: [NSLayoutConstraint] = []
    private var outgoingConstraints: [NSLayoutConstraint] = []

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        bubble.layer.cornerRadius = 8
        bubble.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.textColor = .label
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(messageLabel)
        contentView.addSubview(avatar)
        contentView.addSubview(bubble)

        let maxWidth = bubble.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.68)
        NSLayoutConstraint.activate([
            avatar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubble.topAnchor.constraint(equalTo: avatar.topAnchor),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: avatar.bottomAnchor, constant: 8),
            maxWidth,
            messageLabel.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -10),
            messageLabel.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12),
        ])
        incomingConstraints = [
            avatar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            bubble.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 8),
        ]
        outgoingConstraints = [
            avatar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            bubble.trailingAnchor.constraint(equalTo: avatar.leadingAnchor, constant: -8),
        ]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with message: SPLKChatMessage, sender: SPLKChatContact) {
        avatar.configure(with: sender)
        messageLabel.text = message.text
        bubble.backgroundColor = message.isOutgoing ? .splkChatOutgoingBubble : .splkChatIncomingBubble
        NSLayoutConstraint.deactivate(message.isOutgoing ? incomingConstraints : outgoingConstraints)
        NSLayoutConstraint.activate(message.isOutgoing ? outgoingConstraints : incomingConstraints)
    }
}
