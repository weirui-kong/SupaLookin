//
//  LKMenuPopoverAppsListController.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/5.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

enum MenuPopoverAppsListControllerEventSource {
    case reloadButton
    case noConnectionTips
    case appButton
}

final class LKMenuPopoverAppsListController: LKBaseViewController {

    private var appViews: [LKLaunchAppView] = []

    private var titleLabel: LKLabel?
    private var subtitleLabel: LKLabel?
    private let tutorialControl = LKTextControl()

    private let appViewInterSpace: CGFloat = 1
    private let insets = NSEdgeInsets(top: 9, left: 18, bottom: 35, right: 14)
    private let titleMarginBottom: CGFloat = 3
    private let subtitleMarginBottom: CGFloat = 5

    var didSelectApp: ((LKInspectableApp?) -> Void)?

    init(apps: [LKInspectableApp], source: MenuPopoverAppsListControllerEventSource) {
        super.init(containerView: nil)

        var title: String?
        var subtitle: String?
        switch source {
        case .reloadButton, .noConnectionTips:
            title = NSLocalizedString("Connection lost", comment: "")
            if apps.isEmpty {
                subtitle = NSLocalizedString("And no inspectable app was found", comment: "")
            } else if apps.count == 1 {
                subtitle = NSLocalizedString("Click the screenshot below to Change App", comment: "")
            } else {
                subtitle = String(format: NSLocalizedString("Other %@ apps were found", comment: ""), NSNumber(value: apps.count))
            }
        case .appButton:
            if !apps.isEmpty {
                if apps.count == 1 {
                    title = NSLocalizedString("1 active app was found", comment: "")
                } else {
                    title = String(format: NSLocalizedString("%@ active apps were found", comment: ""), NSNumber(value: apps.count))
                }
                subtitle = NSLocalizedString("Click the screenshot below to inspect", comment: "")
            } else {
                title = NSLocalizedString("No inspectable app was found", comment: "")
            }
        }

        appViews = apps.map { app in
            let view = LKLaunchAppView()
            view.compactLayout = true
            view.app = app
            view.clickAction = { [unowned self] control in
                self.handleClickAppView(control as! LKLaunchAppView)
            }
            self.view.addSubview(view)
            return view
        }

        if let title, !title.isEmpty {
            let label = LKLabel()
            label.alignment = .center
            label.font = .systemFont(ofSize: 14)
            label.textColor = .labelColor
            label.stringValue = title
            view.addSubview(label)
            titleLabel = label
        }

        if let subtitle, !subtitle.isEmpty {
            let label = LKLabel()
            label.alignment = .center
            label.font = .systemFont(ofSize: 12)
            label.textColor = .labelColor
            label.stringValue = subtitle
            view.addSubview(label)
            subtitleLabel = label
        }

        tutorialControl.layer?.cornerRadius = 4
        tutorialControl.label.stringValue = NSLocalizedString("Can't see your app ?", comment: "")
        tutorialControl.label.textColor = .linkColor
        tutorialControl.label.font = .systemFont(ofSize: 12)
        tutorialControl.adjustAlphaWhenClick = true
        tutorialControl.clickAction = { [unowned self] _ in
            self.handleTutorial()
        }
        view.addSubview(tutorialControl)
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        var y = insets.top
        if let titleLabel {
            titleLabel.fillWidth().fitHeight().setY(y)
            y = titleLabel.frame.maxY + titleMarginBottom
        }
        if let subtitleLabel {
            subtitleLabel.fillWidth().fitHeight().setY(y)
            y = subtitleLabel.frame.maxY + subtitleMarginBottom
        }

        if !appViews.isEmpty {
            var posX: CGFloat = 0
            for appView in appViews {
                appView.fitSize().setX(posX).setY(y)
                posX = appView.frame.maxX + appViewInterSpace
            }
            appViews.centerGroupHorizontally()

            tutorialControl.fitSize().centerHorizontally().offset(x: 3).alignBottom(10)
        } else {
            tutorialControl.fitSize().centerHorizontally().offset(x: 3)
            if subtitleLabel?.isVisible == true {
                tutorialControl.setY(y)
            } else {
                tutorialControl.setY(y + 8)
            }
            ([titleLabel, subtitleLabel, tutorialControl] as [NSView?]).compactMap { $0 }.visibleViews.centerGroupVertically()
        }
    }

    private func handleClickAppView(_ view: LKLaunchAppView) {
        didSelectApp?(view.app)
    }

    func bestSize() -> NSSize {
        if appViews.isEmpty {
            return NSSize(width: 245, height: 80)
        }
        var width = insets.left + insets.right + CGFloat(appViews.count - 1) * appViewInterSpace
        var appViewMaxHeight: CGFloat = 0
        for appView in appViews {
            let size = appView.sizeThatFits(.max)
            width += size.width
            appViewMaxHeight = max(appViewMaxHeight, size.height)
        }

        var height = insets.top + insets.bottom + appViewMaxHeight
        if let titleLabel {
            let titleSize = titleLabel.sizeThatFits(.max)
            height += titleSize.height + titleMarginBottom
            width = max(width, titleSize.width + insets.left + insets.right)
        }
        if let subtitleLabel {
            let subtitleSize = subtitleLabel.sizeThatFits(.max)
            height += subtitleSize.height + subtitleMarginBottom
            width = max(width, subtitleSize.width + insets.left + insets.right)
        }

        return NSSize(width: width, height: height)
    }

    private func handleTutorial() {
        NSWorkspace.shared.open(URL(string: "https://lookin.work/faq/cannot-see/")!)
    }
}
