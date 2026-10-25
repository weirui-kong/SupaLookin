//
//  LKNavigationManager.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/3.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKNavigationManager: NSObject, NSWindowDelegate {

    static let sharedInstance = LKNavigationManager()

    private(set) var launchWindowController: LKLaunchWindowController?
    private(set) var staticWindowController: LKStaticWindowController?
    var readWindowControllers: [LKReadWindowController] = []

    private var preferenceWindowController: LKPreferenceWindowController?
    private var jsonWindowController: LKJSONAttributeWindowController?
    private var aboutWindowController: LKAboutWindowController?

    var windowTitleBarHeight: CGFloat = 0

    private override init() {
        super.init()
    }

    func showLaunch() {
        let wc = LKLaunchWindowController()
        launchWindowController = wc
        wc.showWindow(self)
    }

    func showStaticWorkspace() {
        if staticWindowController == nil {
            let wc = LKStaticWindowController()
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
            let wc = LKPreferenceWindowController()
            wc.window?.delegate = self
            preferenceWindowController = wc
        }
        preferenceWindowController?.showWindow(self)
    }

    func showAbout() {
        if aboutWindowController == nil {
            let wc = LKAboutWindowController()
            wc.window?.delegate = self
            aboutWindowController = wc
        }
        aboutWindowController?.showWindow(self)
    }

    func currentKeyWindowController() -> LKWindowController? {
        NSApp.keyWindow?.windowController as? LKWindowController
    }

    func showReader(withFilePath filePath: String?) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath ?? ""))

        let dataObj: Any?
        do {
            dataObj = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSObject.self], from: data)
        } catch {
            dataObj = nil
        }
        guard let dataObj else {
            // 比如拖了一个 pdf 格式的文件进来就会走到这里
            throw NSError(domain: LookinErrorDomain, code: LookinErrCode_UnsupportedFileType, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Failed to open the document.", comment: ""),
                NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString("The file type is not supported.", comment: ""),
            ])
        }

        // verifyHierarchyFile: reports a non-LookinHierarchyFile object as an inner error
        guard let file = dataObj as? LookinHierarchyFile else {
            throw LookinError.inner
        }
        if let verifyError = LookinHierarchyFile.verifyHierarchyFile(file) {
            // 有问题，无法打开
            throw verifyError
        }

        // 文件校验无误
        let title = FileManager.default.displayName(atPath: filePath ?? "")
        showReader(withHierarchyFile: file, title: title)
    }

    func showReader(withHierarchyFile file: LookinHierarchyFile, title: String?) {
        let wc = LKReadWindowController(file: file)
        wc.window?.title = title ?? ""
        wc.window?.delegate = self
        wc.showWindow(self)
        readWindowControllers.append(wc)
    }

    func showJsonWindow(_ json: String) {
        if jsonWindowController == nil {
            let wc = LKJSONAttributeWindowController()
            wc.window?.delegate = self
            jsonWindowController = wc
        }
        (jsonWindowController?.contentViewController as? LKJSONAttributeViewController)?.render(withJSON: json)
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
            closingWindow?.saveFrame(usingName: LKWindowSizeName_Static)
        } else if closingWindow != nil && closingWindow === aboutWindowController?.window {
            aboutWindowController = nil
        } else if let index = readWindowControllers.firstIndex(where: { $0.window === closingWindow }) {
            readWindowControllers.remove(at: index)
        }
    }
}
