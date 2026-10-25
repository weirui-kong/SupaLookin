//
//  LKHierarchyHandlersPopoverController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/8/11.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKHierarchyHandlersPopoverController: LKBaseViewController {

    private let scrollView = NSScrollView()
    private var itemViews: [LKHierarchyHandlersPopoverItemView] = []
    private let verInset: CGFloat = 0

    init(displayItem: LookinDisplayItem, editable: Bool) {
        super.init(containerView: nil)
        let documentView = LKBaseView()
        scrollView.documentView = documentView

        itemViews = (displayItem.eventHandlers ?? []).enumerated().map { idx, handler in
            let view = LKHierarchyHandlersPopoverItemView(eventHandler: handler, editable: editable)
            documentView.addSubview(view)
            view.needTopBorder = idx > 0
            view.isHidden = false
            return view
        }
    }

    override func makeContainerView() -> NSView {
        scrollView.drawsBackground = false
        return scrollView
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        scrollView.documentView?.fillWidth().setY(0)

        var maxY: CGFloat = 0
        let visibleViews = itemViews.visibleViews
        for (idx, view) in visibleViews.enumerated() {
            let prevView = idx > 0 ? itemViews[idx - 1] : nil
            let y = prevView?.frame.maxY ?? verInset
            view.fillWidth().fitHeight().setY(y)

            if idx == visibleViews.count - 1 {
                maxY = view.frame.maxY
            }
        }
        scrollView.documentView?.setHeight(maxY)
    }

    func neededSize() -> NSSize {
        var resultSize = NSSize(width: 0, height: verInset * 2)
        for itemView in itemViews where !itemView.isHidden {
            let itemSize = itemView.sizeThatFits(.max)
            resultSize.width = max(resultSize.width, itemSize.width)
            resultSize.height += itemSize.height
        }
        return resultSize
    }
}
