//
//  SPLKReloadSingleItemUpdateTaskMaker.swift
//  SupaLookin
//
//  Created by likai.123 on 2024/3/3.
//  Copyright © 2024 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import SPLKServer

enum SPLKReloadSingleItemUpdateTaskMaker {

    static func make(with item: SPLKDisplayItem?) -> [SPLKStaticAsyncUpdateTask]? {
        guard let item, !SPLKStaticAsyncUpdateManager.sharedInstance.isUpdating else {
            assertionFailure()
            return nil
        }
        var tasks: [SPLKStaticAsyncUpdateTask] = []
        if item.doNotFetchScreenshotReason == .fetchScreenshotPermitted {
            let task = self.task(from: item)
            task.taskType = .groupScreenshot
            tasks.append(task)

            if item.isExpandable {
                let task2 = self.task(from: item)
                task2.taskType = .soloScreenshot
                tasks.append(task2)
            }
        } else {
            let task = self.task(from: item)
            task.taskType = .noScreenshot
            tasks.append(task)
        }
        tasks.first?.needBasisVisualInfo = true
        return tasks
    }

    private static func task(from item: SPLKDisplayItem) -> SPLKStaticAsyncUpdateTask {
        let task = SPLKStaticAsyncUpdateTask()
        task.oid = item.layerObject?.oid ?? 0
        task.frameSize = item.frame.size
        task.clientReadableVersion = SPLKHelper.splkReadableVersion
        return task
    }
}
