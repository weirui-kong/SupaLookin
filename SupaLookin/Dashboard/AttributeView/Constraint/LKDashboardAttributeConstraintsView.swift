//
//  LKDashboardAttributeConstraintsView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/9/12.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKDashboardAttributeConstraintsView: LKDashboardAttributeView {

    private var textControls: [LKDashboardAttributeConstraintsItemControl] = []

    private let verInterSpace: CGFloat = 8

    override func renderWithAttribute() {
        super.renderWithAttribute()

        let rawData = attribute?.value as? [LookinAutoLayoutConstraint] ?? []
        let sortedRawData = sortedRawData(from: rawData)

        textControls.dequeue(count: sortedRawData.count, add: { _ in
            let control = LKDashboardAttributeConstraintsItemControl()
            control.clickAction = { [unowned self] control in
                self.handleClickItem(control as! LKDashboardAttributeConstraintsItemControl)
            }
            self.addSubview(control)
            return control
        }, notDequeued: { _, control in
            control.isHidden = true
        }, doNext: { idx, control in
            control.isHidden = false
            control.constraint = sortedRawData[idx]
            control.needsLayout = true
        })
        needsLayout = true
    }

    override func layout() {
        super.layout()

        var y: CGFloat = 0
        for control in textControls where !control.isHidden {
            control.fillSuperview().fitHeight().setY(y)
            y = control.frame.maxY + verInterSpace
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        let visibleControls = textControls.filter { !$0.isHidden }
        var size = limitedSize
        size.height = visibleControls.enumerated().reduce(0) { accumulator, element in
            let (idx, control) = element
            var result = accumulator + control.sizeThatFits(limitedSize).height
            if idx > 0 {
                result += verInterSpace
            }
            return result
        }
        return size
    }

    private func sortedRawData(from rawData: [LookinAutoLayoutConstraint]) -> [LookinAutoLayoutConstraint] {
        (rawData as NSArray).sortedArray { obj1, obj2 in
            let obj1 = obj1 as! LookinAutoLayoutConstraint
            let obj2 = obj2 as! LookinAutoLayoutConstraint
            if obj1.effective != obj2.effective {
                return obj1.effective ? .orderedAscending : .orderedDescending
            }

            if obj1.firstItemType.rawValue > obj2.firstItemType.rawValue {
                return .orderedDescending
            } else if obj1.firstItemType.rawValue < obj2.firstItemType.rawValue {
                return .orderedAscending
            }

            if obj1.firstAttribute > obj2.firstAttribute {
                return .orderedDescending
            } else if obj1.firstAttribute < obj2.firstAttribute {
                return .orderedAscending
            }

            return .orderedSame
        } as! [LookinAutoLayoutConstraint]
    }

    private func handleClickItem(_ control: LKDashboardAttributeConstraintsItemControl) {
        guard let constraint = control.constraint else { return }
        let vc = LKConstraintPopoverController(constraint: constraint)

        let popover = NSPopover()
        popover.animates = false
        popover.behavior = .transient
        popover.contentSize = vc.contentSize()
        popover.contentViewController = vc
        vc.requestJumpingToObject = { [weak popover, weak self] lookinObj in
            popover?.close()

            guard let dataSource = self?.dashboardViewController?.currentDataSource() else {
                return
            }
            let item = dataSource.displayItem(withOid: lookinObj.oid)
            // 注意这里要先 expand 然后再 select 以使得可以滚动到目标位置
            if let item, !item.displayingInHierarchy {
                dataSource.expandToShowItem(item)
            }
            dataSource.selectedItem = item
        }
        popover.show(relativeTo: NSRect(x: 0, y: 0, width: control.bounds.size.width, height: control.bounds.size.height), of: control, preferredEdge: .maxX)
    }
}
