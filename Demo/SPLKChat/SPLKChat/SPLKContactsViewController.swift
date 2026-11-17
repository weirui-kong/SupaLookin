//
//  SPLKContactsViewController.swift
//  SPLKChat
//
//  Created by Weirui Kong on 2026/11/18.
//

import UIKit

final class SPLKContactsViewController: UITableViewController, UISearchResultsUpdating {

    private let searchController = UISearchController(searchResultsController: nil)
    private var sections: [(letter: String, contacts: [SPLKChatContact])] = []

    init() {
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(SPLKContactCell.self, forCellReuseIdentifier: SPLKContactCell.reuseIdentifier)
        tableView.rowHeight = 56
        tableView.sectionIndexColor = .secondaryLabel
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search"
        searchController.searchBar.searchTextField.accessibilityIdentifier = "contacts.search"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        rebuildSections(query: "")
    }

    func updateSearchResults(for searchController: UISearchController) {
        rebuildSections(query: searchController.searchBar.text ?? "")
    }

    private func rebuildSections(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let matches = SPLKChatStore.shared.contacts
            .filter { trimmed.isEmpty || $0.name.localizedCaseInsensitiveContains(trimmed) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let grouped = Dictionary(grouping: matches) { String($0.name.prefix(1)).uppercased() }
        sections = grouped.keys.sorted().map { (letter: $0, contacts: grouped[$0]!) }
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].contacts.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].letter
    }

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        sections.map(\.letter)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SPLKContactCell.reuseIdentifier, for: indexPath) as! SPLKContactCell
        cell.configure(with: sections[indexPath.section].contacts[indexPath.row])
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let detail = SPLKContactDetailViewController(contact: sections[indexPath.section].contacts[indexPath.row])
        detail.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(detail, animated: true)
    }
}

final class SPLKContactCell: UITableViewCell {

    static let reuseIdentifier = "SPLKContactCell"

    private let avatar = SPLKAvatarView(size: 38)
    private let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(avatar)
        contentView.addSubview(nameLabel)
        separatorInset = UIEdgeInsets(top: 0, left: 66, bottom: 0, right: 0)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatar.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with contact: SPLKChatContact) {
        avatar.configure(with: contact)
        nameLabel.text = contact.name
        accessibilityIdentifier = "contacts.row.\(contact.id)"
    }
}

final class SPLKContactDetailViewController: UIViewController {

    private let contact: SPLKChatContact

    init(contact: SPLKChatContact) {
        self.contact = contact
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let avatar = SPLKAvatarView(size: 72)
        avatar.configure(with: contact)
        let nameLabel = UILabel()
        nameLabel.text = contact.name
        nameLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        let statusLabel = UILabel()
        statusLabel.text = contact.status
        statusLabel.textColor = .secondaryLabel

        var configuration = UIButton.Configuration.filled()
        configuration.title = "Send Message"
        configuration.image = UIImage(systemName: "message.fill")
        configuration.imagePadding = 8
        configuration.baseBackgroundColor = .splkChatAccent
        let messageButton = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            self?.openConversation()
        })
        messageButton.accessibilityIdentifier = "contact.message"

        var callConfiguration = UIButton.Configuration.gray()
        callConfiguration.title = "Voice Call"
        callConfiguration.image = UIImage(systemName: "phone.fill")
        callConfiguration.imagePadding = 8
        let callButton = UIButton(configuration: callConfiguration, primaryAction: UIAction { [weak self] _ in
            let alert = UIAlertController(title: "Calling isn't available", message: "This demo has no calls.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        })

        let stack = UIStackView(arrangedSubviews: [avatar, nameLabel, statusLabel, messageButton, callButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(32, after: statusLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            messageButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            callButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func openConversation() {
        let conversation = SPLKConversationViewController(conversation: SPLKChatStore.shared.conversation(with: contact))
        navigationController?.pushViewController(conversation, animated: true)
    }
}
