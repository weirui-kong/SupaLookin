//
//  LKBaseViewController.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/8/28.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine

class LKBaseViewController: NSViewController {

    private(set) var isViewAppeared = false

    private(set) var connectionTipsView: LKRedTipsView?

    var cancellables = Set<AnyCancellable>()

    /**
     如果使用该初始化方法，则 controller.view 会被赋值为传入的 view。
     如果使用普通的 init 方法，或该方法传入 nil，则 controller 会自动创建一个 view，即 makeContainerView()
     */
    init(containerView view: NSView?) {
        super.init(nibName: nil, bundle: nil)
        self.view = view ?? makeContainerView()
    }

    convenience init() {
        self.init(containerView: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NSLog("%@ dealloc", String(describing: type(of: self)))
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        isViewAppeared = true
    }

    override var view: NSView {
        didSet {
            setUpConnectionTipsIfNeeded(in: view)
        }
    }

    private func setUpConnectionTipsIfNeeded(in view: NSView) {
        guard shouldShowConnectionTips else {
            return
        }
        let tipsView = LKRedTipsView()
        tipsView.isHidden = true
        tipsView.title = NSLocalizedString("Reconnecting…", comment: "")
        tipsView.buttonText = NSLocalizedString("Change App", comment: "")
        tipsView.clickAction = { [weak self] _ in
            self?.handleClickReconnectTips()
        }
        connectionTipsView = tipsView

        LKAppsManager.sharedInstance.inspectingAppPublisher
            .sink { [weak self, weak view] app in
                guard let self, let tipsView = self.connectionTipsView else {
                    return
                }
                if let app {
                    tipsView.endAnimation()
                    tipsView.isHidden = true
                    tipsView.setImage(byDeviceType: app.appInfo?.deviceType ?? .simulator)
                } else {
                    if tipsView.superview == nil {
                        view?.addSubview(tipsView)
                    }
                    tipsView.isHidden = false
                    tipsView.startAnimation()
                    self.view.needsLayout = true
                }
            }
            .store(in: &cancellables)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        if let connectionTipsView, connectionTipsView.isVisible {
            let windowTitleHeight = LKNavigationManager.sharedInstance.windowTitleBarHeight
            connectionTipsView.fitSize().centerHorizontally().setY(windowTitleHeight + 10)
        }
    }

    private func handleClickReconnectTips() {
        let wc = view.window?.windowController
        let staticWc = LKNavigationManager.sharedInstance.staticWindowController

        if let staticWc, wc === staticWc {
            staticWc.popupAllInspectableApps(withSource: .noConnectionTips)
        } else if let staticWc {
            staticWc.showWindow(self)
            staticWc.popupAllInspectableApps(withSource: .noConnectionTips)
        } else {
            assertionFailure()
        }
    }

    // MARK: - Subclassing hooks

    func makeContainerView() -> NSView {
        LKBaseView()
    }

    /// 是否在连接断开时显示 tips，默认为 false
    var shouldShowConnectionTips: Bool {
        false
    }
}
