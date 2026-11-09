//
//  SPLKNavigationManager.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/3.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import SPLKServer

final class SPLKNavigationManager: NSObject, NSWindowDelegate {

    static let sharedInstance = SPLKNavigationManager()

    private(set) var launchWindowController: SPLKLaunchWindowController?
    private(set) var staticWindowController: SPLKStaticWindowController?
    var readWindowControllers: [SPLKReadWindowController] = []

    private var preferenceWindowController: SPLKPreferenceWindowController?
    private var jsonWindowController: SPLKJSONAttributeWindowController?
    private var aboutWindowController: SPLKAboutWindowController?

    var windowTitleBarHeight: CGFloat = 0

    private override init() {
        super.init()
    }

    func showLaunch() {
        let wc = SPLKLaunchWindowController()
        launchWindowController = wc
        wc.showWindow(self)
    }

    func showStaticWorkspace() {
        if staticWindowController == nil {
            let wc = SPLKStaticWindowController()
            wc.window?.delegate = self
            staticWindowController = wc
        }
        staticWindowController?.showWindow(self)
    }

    func closeLaunch() {
        launchWindowController?.close()
        launchWindowController = nil
    }

    func showPreference() {
        if preferenceWindowController == nil {
            let wc = SPLKPreferenceWindowController()
            wc.window?.delegate = self
            preferenceWindowController = wc
        }
        preferenceWindowController?.showWindow(self)
    }

    func showAbout() {
        if aboutWindowController == nil {
            let wc = SPLKAboutWindowController()
            wc.window?.delegate = self
            aboutWindowController = wc
        }
        aboutWindowController?.showWindow(self)
    }

    func currentKeyWindowController() -> SPLKWindowController? {
        NSApp.keyWindow?.windowController as? SPLKWindowController
    }

    func showReader(withFilePath filePath: String?) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath ?? ""))

        let dataObj: Any?
        let isLegacy: Bool
        do {
            (dataObj, isLegacy) = try SPLKHierarchyFile.unarchivedObject(from: data)
        } catch {
            dataObj = nil
            isLegacy = false
        }
        guard let dataObj else {
            // 比如拖了一个 pdf 格式的文件进来就会走到这里
            throw NSError(domain: SPLKErrorDomain, code: SPLKErrCode_UnsupportedFileType, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Failed to open the document.", comment: ""),
                NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString("The file type is not supported.", comment: ""),
            ])
        }

        // verifyHierarchyFile: reports a non-SPLKHierarchyFile object as an inner error
        guard let file = dataObj as? SPLKHierarchyFile else {
            throw SPLKError.inner
        }
        if let verifyError = file.verificationError(isLegacy: isLegacy) {
            // 有问题，无法打开
            throw verifyError
        }

        // 文件校验无误
        let title = FileManager.default.displayName(atPath: filePath ?? "")
        showReader(withHierarchyFile: file, title: title)
    }

    func showReader(withHierarchyFile file: SPLKHierarchyFile, title: String?) {
        let wc = SPLKReadWindowController(file: file)
        wc.window?.title = title ?? ""
        wc.window?.delegate = self
        wc.showWindow(self)
        readWindowControllers.append(wc)
    }

    func showJsonWindow(_ json: String) {
        if jsonWindowController == nil {
            let wc = SPLKJSONAttributeWindowController()
            wc.window?.delegate = self
            jsonWindowController = wc
        }
        (jsonWindowController?.contentViewController as? SPLKJSONAttributeViewController)?.render(withJSON: json)
        jsonWindowController?.showWindow(self)
    }

    // MARK: - NSWindowDelegate

    /**
     staticWindowController 关闭时不要直接释放，因为点击某些窗口的“连接已断开” tips 可能需要唤起 static 窗口来切换 App
     */
    func windowWillClose(_ notification: Notification) {
        let closingWindow = notification.object as? NSWindow

        if closingWindow != nil && closingWindow === preferenceWindowController?.window {
            preferenceWindowController = nil
        } else if closingWindow != nil && closingWindow === staticWindowController?.window {
            closingWindow?.saveFrame(usingName: SPLKWindowSizeName_Static)
        } else if closingWindow != nil && closingWindow === aboutWindowController?.window {
            aboutWindowController = nil
        } else if let index = readWindowControllers.firstIndex(where: { $0.window === closingWindow }) {
            readWindowControllers.remove(at: index)
        }
    }
}
