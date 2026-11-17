//
//  SPLKMeViewController.swift
//  SPLKChat
//
//  Created by Weirui Kong on 2026/11/18.
//

import UIKit

final class SPLKMeViewController: UITableViewController {

    private enum Setting: String, CaseIterable {
        case newMessageAlerts = "New Message Alerts"
        case sound = "Sound"
        case vibrate = "Vibrate"
        case readReceipts = "Read Receipts"
        case darkMode = "Dark Mode"
    }

    private var values: [Setting: Bool] = [.newMessageAlerts: true, .sound: true, .vibrate: false, .readReceipts: true, .darkMode: false]
    private var fontScale: Float = 0.5

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        values[.darkMode] = traitCollection.userInterfaceStyle == .dark
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        4
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: 1
        case 1: Setting.allCases.count
        case 2: 1
        default: 2
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 1: "Settings"
        case 2: "Chat Font Size"
        default: nil
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath.section == 0 ? 96 : UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            return SPLKProfileCell(contact: SPLKChatStore.shared.me)
        case 1:
            let setting = Setting.allCases[indexPath.row]
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = setting.rawValue
            cell.selectionStyle = .none
            let toggle = UISwitch()
            toggle.isOn = values[setting] ?? false
            toggle.onTintColor = .splkChatAccent
            toggle.accessibilityIdentifier = "me.\(setting)"
            toggle.addAction(UIAction { [weak self] action in
                guard let toggle = action.sender as? UISwitch else { return }
                self?.set(setting, toggle.isOn)
            }, for: .valueChanged)
            cell.accessoryView = toggle
            return cell
        case 2:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.selectionStyle = .none
            let slider = UISlider()
            slider.value = fontScale
            slider.minimumValueImage = UIImage(systemName: "textformat.size.smaller")
            slider.maximumValueImage = UIImage(systemName: "textformat.size.larger")
            slider.accessibilityIdentifier = "me.fontSize"
            slider.addAction(UIAction { [weak self] action in
                self?.fontScale = (action.sender as? UISlider)?.value ?? 0.5
            }, for: .valueChanged)
            slider.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(slider)
            NSLayoutConstraint.activate([
                slider.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                slider.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                slider.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
                slider.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
            ])
            return cell
        default:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = indexPath.row == 0 ? "Clear All Chat History" : "Log Out"
            cell.textLabel?.textColor = .systemRed
            cell.textLabel?.textAlignment = .center
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 3 else { return }
        if indexPath.row == 0 {
            let alert = UIAlertController(title: "Clear All Chat History?", message: "This can't be undone.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
                SPLKChatStore.shared.clearAllHistory()
            })
            present(alert, animated: true)
        } else {
            let alert = UIAlertController(title: "Log Out?", message: "This demo keeps you signed in anyway.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Log Out", style: .destructive))
            present(alert, animated: true)
        }
    }

    private func set(_ setting: Setting, _ isOn: Bool) {
        values[setting] = isOn
        if setting == .darkMode {
            view.window?.overrideUserInterfaceStyle = isOn ? .dark : .light
        }
    }
}

final class SPLKProfileCell: UITableViewCell {

    init(contact: SPLKChatContact) {
        super.init(style: .default, reuseIdentifier: nil)
        selectionStyle = .none
        let avatar = SPLKAvatarView(size: 64)
        avatar.configure(with: contact)
        let nameLabel = UILabel()
        nameLabel.text = contact.name
        nameLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        let idLabel = UILabel()
        idLabel.text = "ID: splk_demo · " + contact.status
        idLabel.font = .systemFont(ofSize: 14)
        idLabel.textColor = .secondaryLabel
        let text = UIStackView(arrangedSubviews: [nameLabel, idLabel])
        text.axis = .vertical
        text.spacing = 4
        let row = UIStackView(arrangedSubviews: [avatar, text])
        row.spacing = 14
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            row.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
