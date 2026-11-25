//
//  SPLKDiscoverViewController.swift
//  SPLKChat
//
//  Created by Weirui Kong on 2026/11/18.
//

import CoreLocation
import Photos
import UIKit
import UserNotifications

final class SPLKDiscoverViewController: UITableViewController, CLLocationManagerDelegate {

    private enum Row {
        case feed, photos, notifications, location, alert, textAlert, actionSheet, masks
    }

    private let sections: [(title: String?, rows: [Row])] = [
        (nil, [.feed]),
        ("System Alerts", [.photos, .notifications, .location]),
        ("App Alerts", [.alert, .textAlert, .actionSheet]),
        ("Inspector Cases", [.masks]),
    ]

    private let locationManager = CLLocationManager()
    private var notificationStatus = "Not Asked"
    private var lastAlertResult = ""

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.delegate = self
        refreshNotificationStatus()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshNotificationStatus()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        tableView.reloadData()
    }

    private func refreshNotificationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationStatus = switch settings.authorizationStatus {
            case .notDetermined: "Not Asked"
            case .denied: "Denied"
            case .authorized: "Allowed"
            case .provisional: "Provisional"
            case .ephemeral: "Ephemeral"
            @unknown default: "Unknown"
            }
            tableView.reloadData()
        }
    }

    private var photosStatus: String {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined: "Not Asked"
        case .restricted: "Restricted"
        case .denied: "Denied"
        case .authorized: "Allowed"
        case .limited: "Limited"
        @unknown default: "Unknown"
        }
    }

    private var locationStatus: String {
        switch locationManager.authorizationStatus {
        case .notDetermined: "Not Asked"
        case .restricted: "Restricted"
        case .denied: "Denied"
        case .authorizedAlways: "Always"
        case .authorizedWhenInUse: "While Using"
        @unknown default: "Unknown"
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 2 && !lastAlertResult.isEmpty ? "Last choice: \(lastAlertResult)" : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        let row = sections[indexPath.section].rows[indexPath.row]
        let (title, symbol, color, detail): (String, String, UIColor, String?) = switch row {
        case .feed: ("Moments", "camera.aperture", .systemOrange, nil)
        case .photos: ("Request Photos Access", "photo.on.rectangle", .systemPink, photosStatus)
        case .notifications: ("Request Notifications", "bell.badge", .systemRed, notificationStatus)
        case .location: ("Request Location", "location", .systemBlue, locationStatus)
        case .alert: ("Show Alert", "exclamationmark.bubble", .systemGreen, nil)
        case .textAlert: ("Show Alert with Text Field", "character.cursor.ibeam", .systemTeal, nil)
        case .actionSheet: ("Show Action Sheet", "list.bullet.rectangle", .systemPurple, nil)
        case .masks: ("Masks", "theatermasks", .systemIndigo, nil)
        }
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = detail
        cell.imageView?.image = UIImage(systemName: symbol)
        cell.imageView?.tintColor = color
        cell.accessoryType = row == .feed || row == .masks ? .disclosureIndicator : .none
        cell.accessibilityIdentifier = "discover.\(row)"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let sourceView = tableView.cellForRow(at: indexPath)
        switch sections[indexPath.section].rows[indexPath.row] {
        case .feed:
            let feed = SPLKFeedViewController()
            feed.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(feed, animated: true)
        case .masks:
            showMasks(animated: true)
        case .photos:
            Task {
                _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                tableView.reloadData()
            }
        case .notifications:
            Task {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
                refreshNotificationStatus()
            }
        case .location:
            locationManager.requestWhenInUseAuthorization()
        case .alert:
            let alert = UIAlertController(title: "Delete this chat?", message: "Messages in this chat will be removed from this device.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in self?.record("Cancel") })
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in self?.record("Delete") })
            present(alert, animated: true)
        case .textAlert:
            let alert = UIAlertController(title: "Rename Group", message: "Enter a new group name.", preferredStyle: .alert)
            alert.addTextField { field in
                field.placeholder = "Group name"
                field.accessibilityIdentifier = "discover.textAlert.field"
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in self?.record("Cancel") })
            alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
                self?.record("Save “\(alert?.textFields?.first?.text ?? "")”")
            })
            present(alert, animated: true)
        case .actionSheet:
            let sheet = UIAlertController(title: "Share to", message: nil, preferredStyle: .actionSheet)
            for target in ["Friends", "Moments", "Favorites"] {
                sheet.addAction(UIAlertAction(title: target, style: .default) { [weak self] _ in self?.record(target) })
            }
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in self?.record("Cancel") })
            sheet.popoverPresentationController?.sourceView = sourceView
            sheet.popoverPresentationController?.sourceRect = sourceView?.bounds ?? .zero
            present(sheet, animated: true)
        }
    }

    func showMasks(animated: Bool) {
        let masks = SPLKMasksViewController()
        masks.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(masks, animated: animated)
    }

    private func record(_ result: String) {
        lastAlertResult = result
        tableView.reloadData()
    }
}

final class SPLKFeedViewController: UITableViewController {

    private var posts: [(author: SPLKChatContact, text: String, likes: Int)] = []
    private var liked: Set<Int> = []

    init() {
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Moments"
        tableView.accessibilityIdentifier = "feed.list"
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
        loadPosts(count: 200)
    }

    private func loadPosts(count: Int) {
        let contacts = SPLKChatStore.shared.contacts
        let start = posts.count
        posts += (start..<(start + count)).map { index in
            (author: contacts[index % contacts.count],
             text: "Post #\(index + 1): " + String(repeating: "Lorem ipsum dolor sit amet. ", count: 1 + index % 4),
             likes: (index * 7) % 23)
        }
    }

    @objc private func refresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            posts.removeAll()
            liked.removeAll()
            loadPosts(count: 200)
            tableView.reloadData()
            refreshControl?.endRefreshing()
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        posts.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "post") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "post")
        let post = posts[indexPath.row]
        let isLiked = liked.contains(indexPath.row)
        var content = cell.defaultContentConfiguration()
        content.text = post.author.name
        content.textProperties.color = .link
        content.secondaryText = post.text + "\n♥ \(post.likes + (isLiked ? 1 : 0))"
        content.secondaryTextProperties.numberOfLines = 0
        content.image = UIImage(systemName: isLiked ? "heart.fill" : "heart")
        content.imageProperties.tintColor = isLiked ? .systemRed : .secondaryLabel
        cell.contentConfiguration = content
        cell.accessibilityIdentifier = "feed.row.\(indexPath.row)"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if liked.contains(indexPath.row) {
            liked.remove(indexPath.row)
        } else {
            liked.insert(indexPath.row)
        }
        tableView.reloadRows(at: [indexPath], with: .none)
    }
}
