//
//  SPLKStaticHierarchyController.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/8/4.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import SPLKServer

final class SPLKStaticHierarchyController: SPLKHierarchyController {

    // MARK: - SPLKHierarchyViewDelegate

    override func hierarchyView(_ view: SPLKHierarchyView, needToCancelPreviewOfItem item: SPLKDisplayItem) {
        item.noPreview = true
        dataSource.itemDidChangeNoPreview.send(())
    }

    override func hierarchyView(_ view: SPLKHierarchyView, needToShowPreviewOfItem item: SPLKDisplayItem) {
        item.enumerateSelfAndAncestors { item in
            if item.noPreview {
                item.noPreview = false
            }
            return false
        }
        dataSource.itemDidChangeNoPreview.send(())
    }
}
