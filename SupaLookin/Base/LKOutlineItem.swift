//
//  LKOutlineItem.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/28.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

enum LKOutlineItemStatus {
    case notExpandable
    case expanded
    case collapsed
}

final class LKOutlineItem {

    var subItems: [LKOutlineItem]? {
        didSet {
            status = subItems != nil ? .collapsed : .notExpandable
        }
    }

    var status: LKOutlineItemStatus = .notExpandable

    var titleText: String?

    var image: NSImage?

    private(set) var indentation = 0

    private func flatItems() -> [LKOutlineItem] {
        var array = [self]
        if status == .expanded {
            for item in subItems ?? [] {
                item.indentation = indentation + 1
                array.append(contentsOf: item.flatItems())
            }
        }
        return array
    }

    static func flatItems(fromRootItems items: [LKOutlineItem]?) -> [LKOutlineItem] {
        (items ?? []).flatMap { $0.flatItems() }
    }
}
