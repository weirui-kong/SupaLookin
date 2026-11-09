//
//  SPLKDashboardSectionViewPool.swift
//  SupaLookin
//
//  Created by LikaiMacStudioWork on 2023/10/31.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import SPLKServer

final class SPLKDashboardSectionViewPool {

    private var dequeuedViews = Set<ObjectIdentifier>()
    private var cache: [String: [SPLKDashboardSectionView]] = [:]

    func recycleAll() {
        dequeuedViews.removeAll()
    }

    func dequeView(for section: SPLKAttributesSection) -> SPLKDashboardSectionView {
        let key = cacheKey(for: section)
        for view in cache[key, default: []] {
            if dequeuedViews.contains(ObjectIdentifier(view)) {
                continue
            }
            dequeuedViews.insert(ObjectIdentifier(view))
            return view
        }
        let newView = SPLKDashboardSectionView()
        dequeuedViews.insert(ObjectIdentifier(newView))
        cache[key, default: []].append(newView)
        return newView
    }

    private func cacheKey(for section: SPLKAttributesSection) -> String {
        if !section.isUserCustom() {
            return section.identifier
        }
        return (section.attributes ?? []).map { $0.displayTitle ?? "" }.joined(separator: ",")
    }
}
