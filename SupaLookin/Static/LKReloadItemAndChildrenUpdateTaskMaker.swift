//
//  LKReloadItemAndChildrenUpdateTaskMaker.swift
//  SupaLookin
//
//  Created by likai.123 on 2024/3/3.
//  Copyright © 2024 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import LookinShared

enum LKReloadItemAndChildrenUpdateTaskMaker {

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
        let task = LookinStaticAsyncUpdateTask()
        task.oid = item.layerObject?.oid ?? 0
        task.taskType = .noScreenshot
        task.attrRequest = .notNeed
        task.needBasisVisualInfo = true
        task.needSubitems = true
        task.frameSize = item.frame.size
        task.clientReadableVersion = LKHelper.lookinReadableVersion
        return [task]
    }
}
