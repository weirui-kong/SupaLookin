//
//  SPLKReadHierarchyController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/13.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import SPLKServer

final class SPLKReadHierarchyController: SPLKHierarchyController {

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
