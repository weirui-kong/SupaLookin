//
//  LKReadViewController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/12.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import LookinShared

final class LKReadViewController: LKBaseViewController, NSSplitViewDelegate {

    private(set) var hierarchyDataSource: LKReadHierarchyDataSource!

    private var splitView: LKSplitView!
    private var splitLeftView: NSView!
    private var splitRightView: NSView!

    private var dashboardController: LKDashboardViewController!
    private var hierarchyController: LKReadHierarchyController!
    private var previewController: LKPreviewController!
    private var measureController: LKMeasureController!
    private let focusTipView = LKYellowTipsView()

    init(file: LookinHierarchyFile?, preferenceManager manager: LKPreferenceManager) {
        super.init(containerView: nil)

        hierarchyDataSource = LKReadHierarchyDataSource(file: file, preferenceManager: manager)

        hierarchyController = LKReadHierarchyController(dataSource: hierarchyDataSource)
        addChild(hierarchyController)
        splitLeftView = hierarchyController.view
        splitView.addArrangedSubview(splitLeftView)

        splitRightView = LKBaseView()
        splitView.addArrangedSubview(splitRightView)

        previewController = LKPreviewController(dataSource: hierarchyDataSource)
        splitRightView.addSubview(previewController.view)
        addChild(previewController)

        dashboardController = LKDashboardViewController(readDataSource: hierarchyDataSource)
        splitRightView.addSubview(dashboardController.view)
        addChild(dashboardController)

        measureController = LKMeasureController(dataSource: hierarchyDataSource)
        measureController.view.isHidden = true
        splitRightView.addSubview(measureController.view)
        addChild(measureController)

        focusTipView.image = NSImage(named: "icon_info")
        focusTipView.title = NSLocalizedString("Currently in focus mode", comment: "")
        focusTipView.isHidden = true
        focusTipView.buttonText = NSLocalizedString("Exit", comment: "")
        focusTipView.clickAction = { [unowned self] _ in
            self.hierarchyDataSource.endFocus()
        }
        view.addSubview(focusTipView)

        manager.measureState.subscribe(self) { target, param in
            let isMeasure = param.integerValue != LookinMeasureState.no.rawValue
            target.dashboardController.view.isHidden = isMeasure
            target.measureController.view.isHidden = !isMeasure
        }

        hierarchyDataSource.statePublisher
            .sink { [weak self] state in
                guard let self else { return }
                let isFocus = state == .focus
                self.focusTipView.isHidden = !isFocus
                if isFocus {
                    self.focusTipView.startAnimation()
                } else {
                    self.focusTipView.endAnimation()
                }
                self.view.needsLayout = true
            }
            .store(in: &cancellables)
    }

    override func makeContainerView() -> NSView {
        let splitView = LKSplitView()
        splitView.didFinishFirstLayout = { view in
            view.setPosition(350, ofDividerAt: 0)
        }
        splitView.arrangesAllSubviews = false
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        self.splitView = splitView
        return splitView
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        previewController.view.fillSuperview()
        dashboardController.view.setWidth(DashboardViewWidth).alignRight(0).fillHeight()
        measureController.view.setWidth(MeasureViewWidth).alignRight(DashboardHorInset).fillHeight()

        let windowTitleHeight = LKNavigationManager.sharedInstance.windowTitleBarHeight
        var tipsY = windowTitleHeight + 10
        for tipsView in [focusTipView].visibleViews {
            let midX = hierarchyController.view.frame.width + (previewController.view.frame.width - DashboardViewWidth) / 2.0
            tipsView.fitSize().setY(tipsY).setMidX(midX)
            tipsY = tipsView.frame.maxY + 5
        }
    }

    func currentHierarchyView() -> LKHierarchyView {
        hierarchyController.hierarchyView
    }

    // MARK: - NSSplitViewDelegate

    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        false
    }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        200
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        700
    }
}
