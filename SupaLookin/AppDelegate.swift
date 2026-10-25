//
//  AppDelegate.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/8/4.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import LookinShared

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var launchedToOpenFile = false

    private var cancellables = Set<AnyCancellable>()

    func applicationWillFinishLaunching(_ notification: Notification) {
        LKAppMenuManager.sharedInstance.setup()

        LKPreferenceManager.mainManager.appearanceTypePublisher
            .sink { type in
                switch type {
                case .dark:
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                case .light:
                    NSApp.appearance = NSAppearance(named: .aqua)
                default:
                    NSApp.appearance = nil
                }
            }
            .store(in: &cancellables)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = LKConnectionManager.sharedInstance
        if !launchedToOpenFile {
            LKNavigationManager.sharedInstance.showLaunch()
        }

#if DEBUG
        runTests()
#endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        launchedToOpenFile = true
        do {
            try LKNavigationManager.sharedInstance.showReader(withFilePath: filename)
            return true
        } catch {
            return false
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // 清理打开 UIImageView 的图片时创建的临时文件
        let tempImageFilesToDelete = LKHelper.sharedInstance.tempImageFiles
        if tempImageFilesToDelete.isEmpty {
            return .terminateNow
        }
        for path in tempImageFilesToDelete {
            let isSucc = (try? FileManager.default.removeItem(atPath: path)) != nil
            if !isSucc {
                assertionFailure()
            }
        }
        return .terminateNow
    }

    // MARK: - Test

    private func runTests() {
        // 确保 String 的 value 没有重复
        let allGroupIDs = LookinDashboardBlueprint.groupIDs() ?? []
        if allGroupIDs.count != Set(allGroupIDs).count {
            assertionFailure()
        }

        // 确保 String 的 value 没有重复
        let allSecIDs = allGroupIDs.flatMap { LookinDashboardBlueprint.sectionIDs(forGroupID: $0) ?? [] }
        if allSecIDs.count != Set(allSecIDs).count {
            assertionFailure()
        }

        // 确保 String 的 value 没有重复
        let allAttrIDs = allSecIDs.flatMap { LookinDashboardBlueprint.attrIDs(forSectionID: $0) ?? [] }
        if allAttrIDs.count != Set(allAttrIDs).count {
            assertionFailure()
        }
    }
}
