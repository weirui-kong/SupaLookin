//
//  LKReloadSingleItemUpdateTaskMaker.swift
//  SupaLookin
//
//  Created by likai.123 on 2024/3/3.
//  Copyright © 2024 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import LookinShared

enum LKReloadSingleItemUpdateTaskMaker {

    static func make(with item: LookinDisplayItem?) -> [LookinStaticAsyncUpdateTask]? {
        guard let item, !LKStaticAsyncUpdateManager.sharedInstance.isUpdating else {
            assertionFailure()
            return nil
        }
        let serverVersion = LKAppsManager.sharedInstance.inspectingApp?.appInfo?.serverReadableVersion as String? ?? ""
        let supported = LKVersionComparer.compare(withExpectedVersion: "1.2.7", realVersion: serverVersion)
        if !supported {
            LKHelper.alertErrorText(NSLocalizedString("Operation failed.", comment: ""), NSLocalizedString("Please upgrade the LookinServer SDK version in your iOS project to 1.2.7 or higher.", comment: ""), window: NSApp.keyWindow)
            return nil
        }
        var tasks: [LookinStaticAsyncUpdateTask] = []
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

    private static func task(from item: LookinDisplayItem) -> LookinStaticAsyncUpdateTask {
        let task = LookinStaticAsyncUpdateTask()
        task.oid = item.layerObject?.oid ?? 0
        task.frameSize = item.frame.size
        task.clientReadableVersion = LKHelper.lookinReadableVersion
        return task
    }
}
