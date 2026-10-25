//
//  LKReadHierarchyController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/13.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKReadHierarchyController: LKHierarchyController {

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
