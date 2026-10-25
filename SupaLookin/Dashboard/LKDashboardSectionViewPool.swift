//
//  LKDashboardSectionViewPool.swift
//  SupaLookin
//
//  Created by LikaiMacStudioWork on 2023/10/31.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKDashboardSectionViewPool {

    private var dequeuedViews = Set<ObjectIdentifier>()
    private var cache: [String: [LKDashboardSectionView]] = [:]

    func recycleAll() {
        dequeuedViews.removeAll()
    }

    func dequeView(for section: LookinAttributesSection) -> LKDashboardSectionView {
        let key = cacheKey(for: section)
        for view in cache[key, default: []] {
            if dequeuedViews.contains(ObjectIdentifier(view)) {
                continue
            }
            dequeuedViews.insert(ObjectIdentifier(view))
            return view
        }
        let newView = LKDashboardSectionView()
        dequeuedViews.insert(ObjectIdentifier(newView))
        cache[key, default: []].append(newView)
        return newView
    }

    private func cacheKey(for section: LookinAttributesSection) -> String {
        if !section.isUserCustom() {
            return section.identifier
        }
        return (section.attributes ?? []).map { $0.displayTitle ?? "" }.joined(separator: ",")
    }
}
