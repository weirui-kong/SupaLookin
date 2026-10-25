//
//  LKStaticHierarchyDataSource.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/12/21.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import LookinShared

final class LKStaticHierarchyDataSource: LKHierarchyDataSource {

    static let sharedInstance = LKStaticHierarchyDataSource()

    private(set) var appInfo: LookinAppInfo?

    /// 某些 item 的 frame 发生改变
    let itemsDidChangeFrame = PassthroughSubject<LookinDisplayItem, Never>()

    private var shouldIgnoreFastModeAutoUpdate = false

    private override init() {
        super.init()
    }

    // MARK: - Public

    override func reload(with info: LookinHierarchyInfo, keepState: Bool) {
        super.reload(with: info, keepState: keepState)

        appInfo = info.appInfo

        assert((info.appInfo?.screenScale ?? 0) > 0)
        let screenScale = max(info.appInfo?.screenScale ?? 0, 1)
        // SCNNode 的图片的长和宽均不能超过 16384px，这里再随手减掉 100，注意单位是 px 不是 pt
        let maxLengthInPx = LookinNodeImageMaxLengthInPx - 100
        for obj in flatItems {
            let widthInPx = obj.frame.size.width * screenScale
            let heightInPx = obj.frame.size.height * screenScale
            if widthInPx > maxLengthInPx || heightInPx > maxLengthInPx {
                obj.doNotFetchScreenshotReason = .doNotFetchScreenshotForTooLarge
            }
        }

        updateMessageStatus()
        let shouldUpdateAll = !LKPreferenceManager.mainManager.fastMode.currentBOOLValue
        if shouldUpdateAll {
            LKStaticAsyncUpdateManager.sharedInstance.updateAll()
        }
    }

    func modify(with detail: LookinDisplayItemDetail?) {
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
            rawFlatItems = LookinDisplayItem.flatItems(fromHierarchicalItems: rawHierarchyInfo?.displayItems ?? [])
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
                    LKDanceUIAttrMaker.makeDanceUIJumpAttribute(obj, danceSource: danceuiSource)
                }
            }
            buildDisplayingFlatItems()
            shouldIgnoreFastModeAutoUpdate = false
        }
    }

    override func buildDisplayingFlatItems() {
        super.buildDisplayingFlatItems()
        if LKPreferenceManager.mainManager.fastMode.currentBOOLValue && !shouldIgnoreFastModeAutoUpdate {
            LKStaticAsyncUpdateManager.sharedInstance.updateForDisplayingItems()
        }
    }

    override var preferenceManager: LKPreferenceManager {
        LKPreferenceManager.mainManager
    }

    // MARK: - Private

    private func modifyDisplayItem(_ item: LookinDisplayItem, newFrame frame: CGRect, newBounds bounds: CGRect) {
        if item.frame.equalTo(frame) && item.bounds.equalTo(bounds) {
            return
        }
        item.frame = frame
        item.bounds = bounds
        itemsDidChangeFrame.send(item)
    }

    private func updateMessageStatus() {
        if serverSideIsSwiftProject && appInfo?.swiftEnabledInLookinServer == -1 {
            LKMessageManager.sharedInstance.addMessage(LKMessage_SwiftSubspec)
        } else {
            LKMessageManager.sharedInstance.removeMessage(LKMessage_SwiftSubspec)
        }

        if queryIfUsingNewestServerVersion() {
            LKMessageManager.sharedInstance.removeMessage(LKMessage_NewServerVersion)
        } else {
            LKMessageManager.sharedInstance.addMessage(LKMessage_NewServerVersion)
        }
    }

    /// 如果 Server 端使用的是最新版，或者无法判断，那么就返回 true
    func queryIfUsingNewestServerVersion() -> Bool {
        guard let newestVersion = LKServerVersionRequestor.shared.query() else {
            return true
        }
        guard let userVersion = appInfo?.serverReadableVersion as String? else {
            // LookinServer 1.2.3 之前的版本没有该字段
            return false
        }
        return LKVersionComparer.compare(withNewest: newestVersion, user: userVersion)
    }

    override var isReadOnly: Bool {
        false
    }
}
