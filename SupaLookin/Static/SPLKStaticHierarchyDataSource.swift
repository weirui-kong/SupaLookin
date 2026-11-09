//
//  SPLKStaticHierarchyDataSource.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/12/21.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import SPLKServer

final class SPLKStaticHierarchyDataSource: SPLKHierarchyDataSource {

    static let sharedInstance = SPLKStaticHierarchyDataSource()

    private(set) var appInfo: SPLKAppInfo?

    /// 某些 item 的 frame 发生改变
    let itemsDidChangeFrame = PassthroughSubject<SPLKDisplayItem, Never>()

    private var shouldIgnoreFastModeAutoUpdate = false

    private override init() {
        super.init()
    }

    // MARK: - Public

    override func reload(with info: SPLKHierarchyInfo, keepState: Bool) {
        super.reload(with: info, keepState: keepState)

        appInfo = info.appInfo

        assert((info.appInfo?.screenScale ?? 0) > 0)
        let screenScale = max(info.appInfo?.screenScale ?? 0, 1)
        // SCNNode 的图片的长和宽均不能超过 16384px，这里再随手减掉 100，注意单位是 px 不是 pt
        let maxLengthInPx = SPLKNodeImageMaxLengthInPx - 100
        for obj in flatItems {
            let widthInPx = obj.frame.size.width * screenScale
            let heightInPx = obj.frame.size.height * screenScale
            if widthInPx > maxLengthInPx || heightInPx > maxLengthInPx {
                obj.doNotFetchScreenshotReason = .doNotFetchScreenshotForTooLarge
            }
        }

        updateMessageStatus()
        let shouldUpdateAll = !SPLKPreferenceManager.mainManager.fastMode.currentBOOLValue
        if shouldUpdateAll {
            SPLKStaticAsyncUpdateManager.sharedInstance.updateAll()
        }
    }

    func modify(with detail: SPLKDisplayItemDetail?) {
        guard let detail else {
            return
        }
        guard let displayItem = displayItem(withOid: detail.displayItemOid) else {
            assertionFailure()
            return
        }
        if let customDisplayTitle = detail.customDisplayTitle {
            displayItem.customDisplayTitle = customDisplayTitle
        }
        if let danceUISource = detail.danceUISource {
            displayItem.danceuiSource = danceUISource
        }
        if let groupScreenshot = detail.groupScreenshot {
            displayItem.groupScreenshot = groupScreenshot
        }
        if let soloScreenshot = detail.soloScreenshot {
            displayItem.soloScreenshot = soloScreenshot
        }

        if detail.frameValue != nil || detail.boundsValue != nil {
            modifyDisplayItem(displayItem, newFrame: detail.frameValue?.rectValue ?? .zero, newBounds: detail.boundsValue?.rectValue ?? .zero)
        }

        var didChangeHiddenAlpha = false
        if let hiddenValue = detail.hiddenValue, hiddenValue.boolValue != displayItem.isHidden {
            displayItem.isHidden = hiddenValue.boolValue
            didChangeHiddenAlpha = true
        }
        if let alphaValue = detail.alphaValue, alphaValue.floatValue != displayItem.alpha {
            displayItem.alpha = alphaValue.floatValue
            didChangeHiddenAlpha = true
        }
        if didChangeHiddenAlpha {
            itemDidChangeHiddenAlphaValue.send(displayItem)
        }
        var attrChanged = false
        if let attributesGroupList = detail.attributesGroupList, !attributesGroupList.isEmpty {
            displayItem.attributesGroupList = attributesGroupList
            attrChanged = true
        }
        if let customAttrGroupList = detail.customAttrGroupList, !customAttrGroupList.isEmpty {
            displayItem.customAttrGroupList = customAttrGroupList
            attrChanged = true
        }
        if attrChanged {
            itemDidChangeAttrGroup.send(displayItem)
        }
        if let subitems = detail.subitems, (displayItem.subitems?.count ?? 0) > 0 || !subitems.isEmpty {
            // 如果没有这个标记位的话，待会儿的 buildDisplayingItem 在 fastMode 下会触发 update task，而此时上一个 update task 其实还没有结束（此时还在 sendTask 的 subscribe 阶段、还没有到 completion 阶段），因此就会同时有两个 update task，而 task 理论上是不能并发的。所以我们这里先简单的用一个标记位防止一下。
            shouldIgnoreFastModeAutoUpdate = true

            // 可能在 search 或 focus 状态，先退出，否则状态维护太麻烦
            switch state {
            case .focus:
                endFocus()
            case .search:
                endSearch()
            default:
                break
            }

            displayItem.subitems = subitems
            // 根据 subitems 属性打平为二维数组，同时给每个 item 设置 indentLevel
            rawFlatItems = SPLKDisplayItem.flatItems(fromHierarchicalItems: rawHierarchyInfo?.displayItems ?? [])
            flatItems = rawFlatItems
            didReloadHierarchyInfo.send(())

            displayItem.enumerateSelfAndChildren { obj in
                if obj === displayItem {
                    return
                }
                if !obj.isUserCustom && !obj.shouldCaptureImage {
                    obj.enumerateSelfAndChildren { item in
                        item.noPreview = true
                        item.doNotFetchScreenshotReason = .doNotFetchScreenshotForUserConfig
                    }
                }
                if let danceuiSource = obj.customInfo?.danceuiSource, !danceuiSource.isEmpty {
                    SPLKDanceUIAttrMaker.makeDanceUIJumpAttribute(obj, danceSource: danceuiSource)
                }
            }
            buildDisplayingFlatItems()
            shouldIgnoreFastModeAutoUpdate = false
        }
    }

    override func buildDisplayingFlatItems() {
        super.buildDisplayingFlatItems()
        if SPLKPreferenceManager.mainManager.fastMode.currentBOOLValue && !shouldIgnoreFastModeAutoUpdate {
            SPLKStaticAsyncUpdateManager.sharedInstance.updateForDisplayingItems()
        }
    }

    override var preferenceManager: SPLKPreferenceManager {
        SPLKPreferenceManager.mainManager
    }

    // MARK: - Private

    private func modifyDisplayItem(_ item: SPLKDisplayItem, newFrame frame: CGRect, newBounds bounds: CGRect) {
        if item.frame.equalTo(frame) && item.bounds.equalTo(bounds) {
            return
        }
        item.frame = frame
        item.bounds = bounds
        itemsDidChangeFrame.send(item)
    }

    private func updateMessageStatus() {
        if serverSideIsSwiftProject && appInfo?.swiftEnabledInSPLKServer == -1 {
            SPLKMessageManager.sharedInstance.addMessage(SPLKMessage_SwiftSubspec)
        } else {
            SPLKMessageManager.sharedInstance.removeMessage(SPLKMessage_SwiftSubspec)
        }

        if queryIfUsingNewestServerVersion() {
            SPLKMessageManager.sharedInstance.removeMessage(SPLKMessage_NewServerVersion)
        } else {
            SPLKMessageManager.sharedInstance.addMessage(SPLKMessage_NewServerVersion)
        }
    }

    /// 如果 Server 端不比当前 client 自带的 SPLKServer 版本旧，那么就返回 true
    func queryIfUsingNewestServerVersion() -> Bool {
        guard let userVersion = appInfo?.serverReadableVersion as String? else {
            return false
        }
        return SPLKVersionComparer.compare(withNewest: SPLK_SERVER_READABLE_VERSION, user: userVersion)
    }

    override var isReadOnly: Bool {
        false
    }
}
