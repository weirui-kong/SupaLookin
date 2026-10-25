//
//  LKLaunchViewController.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/3.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKLaunchViewController: LKBaseViewController {

    private weak var window: NSWindow?
    private var appViews: [LKLaunchAppView] = []
    private var bottomIndicatorView: LKProgressIndicatorView?
    private var reloadingIndicator: NSProgressIndicator?
    private var noAppsTitleLabel: LKLabel?
    private var tutorialControl: LKTextControl?
    private var isEnteringApp = false
    private var appInfos: [LookinAppInfo]?

    private let appViewInterSpace: CGFloat = 10
    private let contentHorInset: CGFloat = 30
    private let contentHeight: CGFloat = 400

    init(window: NSWindow) {
        self.window = window
        super.init(containerView: nil)
    }

    override func makeContainerView() -> NSView {
        let containerView = LKVisualEffectView()
        containerView.blendingMode = .behindWindow
        containerView.state = .active

        appViews = []

        let tutorialControl = LKTextControl()
        tutorialControl.layer?.cornerRadius = 4
        tutorialControl.label.stringValue = NSLocalizedString("Can't see your app ?", comment: "")
        tutorialControl.label.textColor = .linkColor
        tutorialControl.label.font = .systemFont(ofSize: 12)
        tutorialControl.adjustAlphaWhenClick = true
        tutorialControl.clickAction = { _ in
            LKHelper.openLookinWebsite(withPath: "faq/cannot-see/")
        }
        containerView.addSubview(tutorialControl)
        self.tutorialControl = tutorialControl

        let bottomIndicatorView = LKProgressIndicatorView()
        containerView.addSubview(bottomIndicatorView)
        self.bottomIndicatorView = bottomIndicatorView

        bottomIndicatorView.animate(toProgress: 0.7, duration: 0.5)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // 延时一下，因为如果有 USB 设备被连接，则需要一定时间来使 ConnectionManager 检测到，这个时间实际实验大概 0.1 秒，这里稍微宽裕一点给个 0.2 秒
            self.reload(autoEntering: true)
        }

        return containerView
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        if let reloadingIndicator, let noAppsTitleLabel {
            reloadingIndicator.sizeToFit()
            noAppsTitleLabel.fitSize().setX(reloadingIndicator.frame.maxX + 5).setMidY(reloadingIndicator.frame.midY)
            let group: [NSView] = [reloadingIndicator, noAppsTitleLabel]
            group.centerGroupHorizontally()
            group.forEach { $0.setMidY(view.frame.height * 0.35) }
        }
        tutorialControl?.fitSize().centerHorizontally().offset(x: 3).alignBottom(14)

        var posX = contentHorInset
        for appView in appViews {
            appView.fitSize().setX(posX).setY(30)
            posX = appView.frame.maxX + appViewInterSpace
        }

        bottomIndicatorView?.fillWidth().setHeight(3).alignBottom(0)
    }

    // MARK: - Others

    private func reload(autoEntering autoEnter: Bool) {
        if isEnteringApp {
            return
        }
        let localInfos = appInfos
        Task { [weak self] in
            let apps = await LKAppsManager.sharedInstance.fetchAppInfos(withImage: true, localInfos: localInfos)
            guard let self else {
                return
            }
            self.appInfos = apps.compactMap(\.appInfo)

            if autoEnter && apps.count == 1 && apps.first?.serverVersionError == nil {
                // 进入页面时自动触发的 refetch，并且只有一个 app，则自动拉取 hierarchy
                self.render(withApps: apps)
                self.enterApp(apps[0])
            } else {
                if let bottomIndicatorView = self.bottomIndicatorView, bottomIndicatorView.progress > 0 {
                    bottomIndicatorView.finish(completion: nil)
                }
                self.render(withApps: apps)
                // 每 1.5 秒刷新一次
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.reload(autoEntering: false)
                }
            }
        }
    }

    private func handleClickAppView(_ view: LKLaunchAppView) {
        if isEnteringApp {
            return
        }
        guard let app = view.app else {
            return
        }
        if let serverVersionError = app.serverVersionError {
            if serverVersionError.code == LookinErrCode_ServerVersionTooLow {
                LKHelper.openLookinWebsite(withPath: "faq/server-version-too-low/")
            } else {
                LKHelper.openLookinWebsite(withPath: "faq/server-version-too-high/")
            }
        } else {
            bottomIndicatorView?.animate(toProgress: 0.8, duration: 1)
            enterApp(app)
        }
    }

    private func render(withApps apps: [LKInspectableApp]) {
        if apps.isEmpty {
            window?.setContentSize(NSSize(width: 256, height: contentHeight))

            showNoAppsView()
            appViews.forEach { $0.isHidden = true }
        } else {
            var windowWidth = contentHorInset * 2 + CGFloat(apps.count - 1) * appViewInterSpace
            appViews = appViews.resized(count: apps.count, add: { _ in
                let appView = LKLaunchAppView()
                view.addSubview(appView)
                return appView
            }, remove: { _, appView in
                appView.removeFromSuperview()
            }, doNext: { idx, appView in
                appView.app = apps[idx]
                appView.clickAction = { [weak self] control in
                    if let appView = control as? LKLaunchAppView {
                        self?.handleClickAppView(appView)
                    }
                }
                windowWidth += appView.sizeThatFits(.max).width
            })
            appViews.forEach { $0.isHidden = false }

            window?.setContentSize(NSSize(width: windowWidth, height: contentHeight))

            hideNoAppsViews()
        }

        view.needsLayout = true
    }

    private func enterApp(_ app: LKInspectableApp) {
        if isEnteringApp {
            return
        }
        isEnteringApp = true

        Task { [weak self] in
            do {
                let info = try await app.fetchHierarchyData()
                guard let self else {
                    return
                }
                guard let info else {
                    self.handleEnterAppFail(with: LookinError.inner)
                    return
                }
                LKAppsManager.sharedInstance.inspectingApp = app
                LKStaticHierarchyDataSource.sharedInstance.reload(with: info, keepState: false)

                self.bottomIndicatorView?.finish {
                    LKNavigationManager.sharedInstance.showStaticWorkspace()
                    LKNavigationManager.sharedInstance.closeLaunch()
                }
            } catch {
                self?.handleEnterAppFail(with: error)
            }
        }
    }

    private func handleEnterAppFail(with error: Error) {
        isEnteringApp = false
        bottomIndicatorView?.resetToZero()
        let alert = NSAlert(error: error)
        if let window {
            alert.beginSheetModal(for: window) { _ in
                self.reload(autoEntering: false)
            }
        } else {
            alert.runModal()
            reload(autoEntering: false)
        }
    }

    private func showNoAppsView() {
        if noAppsTitleLabel == nil {
            let label = LKLabel()
            label.textColor = .labelColor
            label.font = .systemFont(ofSize: 14)
            label.stringValue = NSLocalizedString("Searching for inspectable apps", comment: "")
            view.addSubview(label)
            noAppsTitleLabel = label
        }
        if reloadingIndicator == nil {
            let indicator = NSProgressIndicator()
            indicator.isIndeterminate = true
            indicator.style = .spinning
            indicator.controlSize = .small
            view.addSubview(indicator)
            indicator.startAnimation(self)
            reloadingIndicator = indicator
        }
        view.needsLayout = true
    }

    private func hideNoAppsViews() {
        noAppsTitleLabel?.removeFromSuperview()
        noAppsTitleLabel = nil

        reloadingIndicator?.removeFromSuperview()
        reloadingIndicator = nil
    }
}
