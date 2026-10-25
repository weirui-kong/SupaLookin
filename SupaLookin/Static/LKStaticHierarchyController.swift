//
//  LKStaticHierarchyController.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/8/4.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKStaticHierarchyController: LKHierarchyController {

    // MARK: - LKHierarchyViewDelegate

    override func hierarchyView(_ view: LKHierarchyView, needToCancelPreviewOfItem item: LookinDisplayItem) {
        item.noPreview = true
        dataSource.itemDidChangeNoPreview.send(())
    }

    override func hierarchyView(_ view: LKHierarchyView, needToShowPreviewOfItem item: LookinDisplayItem) {
        item.enumerateSelfAndAncestors { item in
            if item.noPreview {
                item.noPreview = false
            }
            return false
        }
        dataSource.itemDidChangeNoPreview.send(())
    }
}
