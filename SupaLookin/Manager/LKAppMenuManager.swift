//
//  LKAppMenuManager.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/3/20.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Sparkle

private let kTag_About = 11
private let kTag_Preferences = 12
private let kTag_CheckUpdates = 13

private let kTag_Reload = 21
private let kTag_Dimension = 22
private let kTag_ZoomIn = 23
private let kTag_ZoomOut = 24
private let kTag_DecreaseInterspace = 25
private let kTag_IncreaseInterspace = 26
private let kTag_Expansion = 27
private let kTag_Filter = 28
private let kTag_OpenInNewWindow = 31
private let kTag_Export = 32

private let kTag_CocoaPods = 51
private let kTag_ShowWebsite = 52
private let kTag_ShowConfig = 53
private let kTag_ShowLookiniOS = 54

private let kTag_GitHub = 57
private let kTag_LookinClientGitHub = 58
private let kTag_LookinServerGitHub = 59

private let kTag_ReportIssues = 60
private let kTag_LookinClientGitHubIssues = 62
private let kTag_LookinServerGitHubIssues = 63
private let kTag_Weibo = 64

private let kTag_CopyPod = 66
private let kTag_CopySPM = 67
private let kTag_MoreIntegrationGuide = 68
private let kTag_Jobs = 69
private let kTag_DocumentCollection = 70
private let kTag_CustomInformation = 71
private let kTag_Acknowledgements = 72

final class LKAppMenuManager: NSObject, NSMenuDelegate {

    static let sharedInstance = LKAppMenuManager()

    private let delegatingTagToAction: [Int: LKAppMenuAction] = [
        kTag_Reload: .reload,
        kTag_Dimension: .dimension,
        kTag_ZoomIn: .zoomIn,
        kTag_ZoomOut: .zoomOut,
        kTag_DecreaseInterspace: .decreaseInterspace,
        kTag_IncreaseInterspace: .increaseInterspace,
        kTag_Expansion: .expansion,
        kTag_Export: .export,
        kTag_OpenInNewWindow: .openInNewWindow,
        kTag_Filter: .filter,
    ]

    private var updaterController: SPUStandardUpdaterController?

    private override init() {
        super.init()
    }

    func setup() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        guard let menu = NSApp.mainMenu else {
            return
        }

        // Lookin
        let menu_lookin = menu.item(at: 0)?.submenu
        menu_lookin?.autoenablesItems = false
        menu_lookin?.delegate = self

        menu_lookin?.item(withTag: kTag_About)?.onAction { _ in
            LKNavigationManager.sharedInstance.showAbout()
        }

        // Lookin - 偏好设置
        menu_lookin?.item(withTag: kTag_Preferences)?.onAction { _ in
            LKNavigationManager.sharedInstance.showPreference()
        }

        menu_lookin?.item(withTag: kTag_CheckUpdates)?.onAction { [weak self] _ in
            self?.updaterController?.checkForUpdates(self)
        }

        // 文件
        let menu_file = menu.item(at: 1)?.submenu
        menu_file?.autoenablesItems = false
        menu_file?.delegate = self

        // 视图
        let menu_view = menu.item(at: 3)?.submenu
        menu_view?.autoenablesItems = false
        menu_view?.delegate = self

        // 帮助
        let menu_help = menu.item(at: 5)?.submenu
        menu_help?.autoenablesItems = true
        menu_help?.delegate = self

        // 帮助 - CocoaPods
        menu_help?.item(withTag: kTag_CocoaPods)?.onAction { _ in
            LKHelper.openLookinWebsite(withPath: "faq/integration-guide/")
        }

        // 帮助 - 官方网站
        menu_help?.item(withTag: kTag_ShowWebsite)?.onAction { _ in
            LKHelper.openLookinOfficialWebsite()
        }

        // 帮助 - 创建配置文件
        menu_help?.item(withTag: kTag_ShowConfig)?.onAction { _ in
            LKHelper.openLookinWebsite(withPath: "faq/config-file/")
        }

        // 帮助 - 在 iOS 上使用 Lookin
        menu_help?.item(withTag: kTag_ShowLookiniOS)?.onAction { _ in
            LKHelper.openLookinWebsite(withPath: "faq/lookin-ios/")
        }

        let sourceCodeMenu = menu_help?.item(withTag: kTag_GitHub)?.submenu
        sourceCodeMenu?.item(withTag: kTag_LookinClientGitHub)?.onAction { _ in
            Self.open("https://github.com/hughkli/Lookin")
        }
        sourceCodeMenu?.item(withTag: kTag_LookinServerGitHub)?.onAction { _ in
            Self.open("https://github.com/QMUI/LookinServer")
        }

        let issuesMenu = menu_help?.item(withTag: kTag_ReportIssues)?.submenu
        issuesMenu?.item(withTag: kTag_LookinClientGitHubIssues)?.onAction { _ in
            Self.open("https://github.com/hughkli/Lookin/issues")
        }
        issuesMenu?.item(withTag: kTag_LookinServerGitHubIssues)?.onAction { _ in
            Self.open("https://github.com/QMUI/LookinServer/issues")
        }
        issuesMenu?.item(withTag: kTag_Weibo)?.onAction { _ in
            Self.open("https://weibo.com/234885306")
        }

        menu_help?.item(withTag: kTag_CopyPod)?.onAction { _ in
            Self.copyToPasteboard("pod 'LookinServer', :configurations => ['Debug']")
        }
        menu_help?.item(withTag: kTag_CopySPM)?.onAction { _ in
            Self.copyToPasteboard("https://github.com/QMUI/LookinServer/")
        }
        menu_help?.item(withTag: kTag_MoreIntegrationGuide)?.onAction { _ in
            Self.open("https://github.com/QMUI/LookinServer/blob/master/README.md")
        }
        menu_help?.item(withTag: kTag_Jobs)?.onAction { _ in
            Self.open("https://bytedance.feishu.cn/docx/SAcgdoQuAouyXAxAqy8cmrT2n4b")
        }
        menu_help?.item(withTag: kTag_DocumentCollection)?.onAction { _ in
            Self.open("https://bytedance.larkoffice.com/docx/Yvv1d57XQoe5l0xZ0ZRc0ILfnWb")
        }
        menu_help?.item(withTag: kTag_CustomInformation)?.onAction { _ in
            Self.open("https://bytedance.larkoffice.com/docx/TRridRXeUoErMTxs94bcnGchnlb")
        }
        menu_help?.item(withTag: kTag_Acknowledgements)?.onAction { _ in
            Self.open("https://qxh1ndiez2w.feishu.cn/docx/YIFjdE4gIolp3hxn1tGckiBxnWf")
        }

        let itemArray = (menu_file?.items ?? []) + (menu_view?.items ?? [])
        for item in itemArray {
            guard let action = delegatingTagToAction[item.tag] else {
                continue
            }
            if item.hasSubmenu {
                if item.tag == kTag_Expansion {
                    // 视图 - 深度
                    for (idx, expansionSubItem) in (item.submenu?.items ?? []).enumerated() {
                        expansionSubItem.representedObject = idx
                        expansionSubItem.onAction { [weak self] subItem in
                            self?.handleExpansion(subItem)
                        }
                    }
                }
            } else {
                item.onAction { [weak self] _ in
                    self?.handleDelegateItem(action)
                }
            }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let wc = LKNavigationManager.sharedInstance.currentKeyWindowController()
        for item in menu.items {
            if let action = delegatingTagToAction[item.tag] {
                item.isEnabled = wc?.supportedAppMenuActions.contains(action) ?? false
            } else {
                item.isEnabled = true
            }
        }
    }

    private func handleDelegateItem(_ action: LKAppMenuAction) {
        guard let wc = LKNavigationManager.sharedInstance.currentKeyWindowController(), wc.supportedAppMenuActions.contains(action) else {
            assertionFailure()
            return
        }
        switch action {
        case .reload:
            wc.appMenuManagerDidSelectReload()
        case .dimension:
            wc.appMenuManagerDidSelectDimension()
        case .zoomIn:
            wc.appMenuManagerDidSelectZoomIn()
        case .zoomOut:
            wc.appMenuManagerDidSelectZoomOut()
        case .decreaseInterspace:
            wc.appMenuManagerDidSelectDecreaseInterspace()
        case .increaseInterspace:
            wc.appMenuManagerDidSelectIncreaseInterspace()
        case .filter:
            wc.appMenuManagerDidSelectFilter()
        case .export:
            wc.appMenuManagerDidSelectExport()
        case .openInNewWindow:
            wc.appMenuManagerDidSelectOpenInNewWindow()
        case .expansion:
            assertionFailure()
        }
    }

    private func handleExpansion(_ item: NSMenuItem) {
        guard let index = item.representedObject as? Int else {
            assertionFailure()
            return
        }
        guard let wc = LKNavigationManager.sharedInstance.currentKeyWindowController(), wc.supportedAppMenuActions.contains(.expansion) else {
            assertionFailure()
            return
        }
        wc.appMenuManagerDidSelectExpansionIndex(index)
    }

    private static func open(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private static func copyToPasteboard(_ string: String) {
        let paste = NSPasteboard.general
        paste.clearContents()
        paste.writeObjects([string as NSString])
    }
}
