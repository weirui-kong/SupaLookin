//
//  LKReadHierarchyDataSource.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/12.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKReadHierarchyDataSource: LKHierarchyDataSource {

    private let readPreferenceManager: LKPreferenceManager

    init(file: LookinHierarchyFile?, preferenceManager manager: LKPreferenceManager) {
        readPreferenceManager = manager
        super.init()

        if let hierarchyInfo = file?.hierarchyInfo {
            reload(with: hierarchyInfo, keepState: false)
        }
        let soloScreenshots = file?.soloScreenshots ?? [:]
        let groupScreenshots = file?.groupScreenshots ?? [:]
        if !soloScreenshots.isEmpty || !groupScreenshots.isEmpty {
            for obj in flatItems {
                let oid = NSNumber(value: obj.layerObject?.oid ?? 0)

                if let soloData = soloScreenshots[oid] {
                    obj.soloScreenshot = NSImage(data: soloData)
                }

                if let groupData = groupScreenshots[oid] {
                    obj.groupScreenshot = NSImage(data: groupData)
                }
            }
        }
    }

    override var preferenceManager: LKPreferenceManager {
        readPreferenceManager
    }
}
