//
//  SPLKReloadItemAndChildrenUpdateTaskMaker.swift
//  SupaLookin
//
//  Created by likai.123 on 2024/3/3.
//  Copyright © 2024 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import SPLKServer

enum SPLKReloadItemAndChildrenUpdateTaskMaker {

    static func make(with item: SPLKDisplayItem?) -> [SPLKStaticAsyncUpdateTask]? {
        guard let item, !SPLKStaticAsyncUpdateManager.sharedInstance.isUpdating else {
            assertionFailure()
            return nil
        }
        let task = SPLKStaticAsyncUpdateTask()
        task.oid = item.layerObject?.oid ?? 0
        task.taskType = .noScreenshot
        task.attrRequest = .notNeed
        task.needBasisVisualInfo = true
        task.needSubitems = true
        task.frameSize = item.frame.size
        task.clientReadableVersion = SPLKHelper.splkReadableVersion
        return [task]
    }
}
