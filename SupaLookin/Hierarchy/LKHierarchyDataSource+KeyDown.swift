//
//  LKHierarchyDataSource+KeyDown.swift
//  SupaLookin
//
//  Created by Hares on 7/17/23.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

extension LKHierarchyDataSource {

    func keyDown(_ event: NSEvent) -> Bool {
        guard let currentItem = selectedItem, let selectedRowIdx = displayingFlatItems.firstIndex(where: { $0 === currentItem }) else {
            return false
        }

        switch event.keyCode {
        case 125: // down
            if let willSelectedItem = displayingFlatItems.element(at: selectedRowIdx + 1) {
                selectedItem = willSelectedItem
                return true
            }
        case 126: // up
            if let willSelectedItem = displayingFlatItems.element(at: selectedRowIdx - 1) {
                selectedItem = willSelectedItem
                return true
            }
        case 123: // left
            if currentItem.isExpandable && currentItem.isExpanded {
                collapseItem(currentItem)
                return true
            } else if let superItem = currentItem.`super`, displayingFlatItems.contains(where: { $0 === superItem }) {
                collapseItem(superItem)
                selectedItem = superItem
                return true
            }
        case 124: // right
            if currentItem.isExpandable && !currentItem.isExpanded {
                expandItem(currentItem)
                return true
            } else {
                let displayItems = displayingFlatItems
                for next in displayItems.dropFirst(selectedRowIdx + 1) where !next.inHiddenHierarchy {
                    selectedItem = next
                    return true
                }
            }
        default:
            break
        }

        return false
    }
}
