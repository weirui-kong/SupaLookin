//
//  LKStaticAsyncUpdateManager.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/2/19.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import Combine
import LookinShared

protocol LKStaticAsyncUpdateManagerDelegate: AnyObject {
    /// 当剩余未完成的 task 数量变化时，该方法会被调用。表示当前一共有 totalCount 个任务，其中 finishedCount 已经完成。
    func detailUpdateTasks(totalCount: Int, finishedCount: Int)
    func detailUpdateReceivedError(_ error: Error)
}

private final class LKDetailUpdateRequest {

    var packages: [LookinStaticAsyncUpdateTasksPackage] = []

    /// 已经收到回复的 task 的数量（但受限于目前的设计，无法知道具体是哪些 task 收到了回复）
    /// detail 有 failureCode 时，也仍然会被算到 finishedTasksCount 里面
    var finishedTasksCount = 0
    var failedTasksCount = 0

    var tasksTotalCount: Int {
        packages.reduce(0) { $0 + ($1.tasks?.count ?? 0) }
    }

    func queryIfContainsTask(_ task: LookinStaticAsyncUpdateTask) -> Bool {
        packages.contains { ($0.tasks as NSArray?)?.contains(task) == true }
    }

    func removeTask(with item: LookinDisplayItem) {
        for pack in packages {
            pack.tasks = pack.tasks?.filter { $0.oid != item.layerObject?.oid }
        }
    }
}

final class LKStaticAsyncUpdateManager {

    static let sharedInstance = LKStaticAsyncUpdateManager()

    weak var delegate: LKStaticAsyncUpdateManagerDelegate?

    /// updateAfterModifyingDisplayItem 的更新进度，分别为已经收到的图像数量、总的图像数量
    /// Like the RACSubject it replaces, it stops delivering for good once it has sent an error.
    let modifyingUpdateProgressSignal = PassthroughSubject<(Int, Int), Error>()

    /// updateAfterModifyingDisplayItem 遇到了错误
    let modifyingUpdateErrorSignal = PassthroughSubject<Error, Never>()

    /// 已经成功收到了所有回复的 request
    private var succeededRequests: [LKDetailUpdateRequest] = []

    /// 已经发送出去、尚未结束的 request
    private var ongoingRequest: LKDetailUpdateRequest?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        dataSource.willReloadHierarchyInfo
            .sink { [weak self] in
                self?.succeededRequests.removeAll()
            }
            .store(in: &cancellables)
    }

    private var dataSource: LKStaticHierarchyDataSource {
        LKStaticHierarchyDataSource.sharedInstance
    }

    var isUpdating: Bool {
        ongoingRequest != nil
    }

    /// 关闭“极速模式”时，reload 之后应该调用该方法来拉取所有 items 的 detail 数据
    func updateAll() {
        assert(!LKPreferenceManager.mainManager.fastMode.currentBOOLValue)

        guard LKAppsManager.sharedInstance.inspectingApp != nil, !dataSource.flatItems.isEmpty else {
            return
        }
        endUpdating()

        let newTasks = makeMaximumTasks()
        if newTasks.isEmpty {
            return
        }
        send(newTasks, completion: nil)
    }

    /// 终止拉取
    func endUpdating() {
        if ongoingRequest == nil {
            return
        }
        NSLog("AsyncUpdate - endUpdating")
        // 这句会触发 send 方法里的 completed 事件，进而导致 delegate 被通知
        LKAppsManager.sharedInstance.inspectingApp?.cancelHierarchyDetailFetching()
    }

    private func makeMaximumTasks() -> [LookinStaticAsyncUpdateTask] {
        // tasks 里的元素顺序很重要：index 更小的 task 会优先被拉取回来展示。所以我们优先把用户可见的图层加进来，这样用户体验更好
        let tasks = NSMutableArray(array: dataSource.displayingFlatItems.compactMap { item -> LookinStaticAsyncUpdateTask? in
            if item.isUserCustom {
                return nil
            }
            if item.doNotFetchScreenshotReason == .fetchScreenshotPermitted {
                if item.isExpandable && item.isExpanded {
                    return task(from: item, type: .soloScreenshot)
                }
                return task(from: item, type: .groupScreenshot)
            }
            return task(from: item, type: .noScreenshot)
        })

        // LookinStaticAsyncUpdateTask's isEqual decides what counts as a duplicate, so this keeps the NSMutableArray containment checks.
        for item in dataSource.flatItems where !item.isUserCustom {
            if item.doNotFetchScreenshotReason == .fetchScreenshotPermitted {
                let task = task(from: item, type: .groupScreenshot)
                if !tasks.contains(task) {
                    tasks.add(task)
                }

                if item.isExpandable {
                    let task2 = self.task(from: item, type: .soloScreenshot)
                    if !tasks.contains(task2) {
                        tasks.add(task2)
                    }
                }
            } else {
                let task = task(from: item, type: .noScreenshot)
                if !tasks.contains(task) {
                    tasks.add(task)
                }
            }
        }
        return tasks.compactMap { $0 as? LookinStaticAsyncUpdateTask }
    }

    private func makePackages(from tasks: [LookinStaticAsyncUpdateTask]) -> [LookinStaticAsyncUpdateTasksPackage] {
        var packages: [LookinStaticAsyncUpdateTasksPackage] = []
        var bufferTasks: [LookinStaticAsyncUpdateTask] = []

        var packageTotalArea: CGFloat = 0
        let packageMaxArea: CGFloat = 2000000
        let packageMaxTasksCount = 100
        for task in tasks {
            let currentArea = task.frameSize.width * task.frameSize.height
            if packageTotalArea + currentArea > packageMaxArea || bufferTasks.count >= packageMaxTasksCount {
                if !bufferTasks.isEmpty {
                    packageTotalArea = 0
                    let package = LookinStaticAsyncUpdateTasksPackage()
                    package.tasks = bufferTasks
                    packages.append(package)
                    bufferTasks.removeAll()
                }
            }

            packageTotalArea += currentArea
            bufferTasks.append(task)
        }

        if !bufferTasks.isEmpty {
            let package = LookinStaticAsyncUpdateTasksPackage()
            package.tasks = bufferTasks
            packages.append(package)
        }
        return packages
    }

    private func task(from item: LookinDisplayItem, type: LookinStaticAsyncUpdateTaskType) -> LookinStaticAsyncUpdateTask {
        let task = LookinStaticAsyncUpdateTask()
        task.oid = item.layerObject?.oid ?? 0
        task.frameSize = item.frame.size
        task.taskType = type
        task.clientReadableVersion = LKHelper.lookinReadableVersion
        return task
    }

    func updateAfterModifyingDisplayItem(_ displayItem: LookinDisplayItem?) {
        guard let app = LKAppsManager.sharedInstance.inspectingApp else {
            return
        }
        guard let displayItem else {
            assertionFailure()
            return
        }

        var tasks: [LookinStaticAsyncUpdateTask] = []
        displayItem.enumerateSelfAndAncestors { item in
            if item.doNotFetchScreenshotReason != .fetchScreenshotPermitted {
                return false
            }
            if item === displayItem && (item.subitems?.count ?? 0) > 0 {
                tasks.append(task(from: item, type: .soloScreenshot))
            }
            tasks.append(task(from: item, type: .groupScreenshot))
            return false
        }

        modifyingUpdateProgressSignal.send((0, 0))

        let screenshotsTotalCount = tasks.count
        var receivedScreenshotsCount = 0
        app.fetchModificationPatch(withTasks: tasks, next: { [weak self] value in
            guard let self else { return }
            let detail = value as? LookinDisplayItemDetail
            LKStaticHierarchyDataSource.sharedInstance.modify(with: detail)

            if detail?.groupScreenshot != nil {
                receivedScreenshotsCount += 1
            }
            if detail?.soloScreenshot != nil {
                receivedScreenshotsCount += 1
            }
            self.modifyingUpdateProgressSignal.send((receivedScreenshotsCount, screenshotsTotalCount))
        }, failure: { [weak self] error in
            assertionFailure()
            self?.modifyingUpdateProgressSignal.send(completion: .failure(error))
        }, completion: { [weak self] in
            self?.modifyingUpdateProgressSignal.send((screenshotsTotalCount, screenshotsTotalCount))
        })
    }

    private func makeMinimumTasks(for items: [LookinDisplayItem]) -> [LookinStaticAsyncUpdateTask] {
        items.compactMap { item -> LookinStaticAsyncUpdateTask? in
            if item.isUserCustom {
                return nil
            }
            if item.appropriateScreenshot != nil {
                // 已经有图像了，无需再拉取（而且既然有图像了，那么 attrs 必然也有了）
                return nil
            }

            let newTask: LookinStaticAsyncUpdateTask
            if item.doNotFetchScreenshotReason == .fetchScreenshotPermitted {
                // 该图层应该有图像（但是现在没有），所以应该拉取图像
                if item.isExpandable && item.isExpanded {
                    newTask = task(from: item, type: .soloScreenshot)
                } else {
                    newTask = task(from: item, type: .groupScreenshot)
                }
            } else {
                // 该图层确实不应该有图像
                if (item.attributesGroupList?.count ?? 0) > 0 {
                    // 有 attr 了，说明已经拉取过了，无需再次拉取
                    return nil
                }
                // 拉取 attr
                newTask = task(from: item, type: .noScreenshot)
            }

            // Client 1.0.7 & Server 1.2.7 开始支持 attrRequest 这个参数
            if (item.attributesGroupList?.count ?? 0) == 0 {
                newTask.attrRequest = .need
            } else {
                newTask.attrRequest = .notNeed
            }

            for req in succeededRequests where req.queryIfContainsTask(newTask) {
                // 该 task 已经请求成功过，不再重复请求
                return nil
            }
            return newTask
        }
    }

    /// 打开“极速模式”时，每次 displayingItems 变化时，都应该调用该方法来拉取可见 items 的 detail 数据（已经拉取过 detail 的 items 不会再次被拉取）
    func updateForDisplayingItems() {
        assert(LKPreferenceManager.mainManager.fastMode.currentBOOLValue)
        guard LKAppsManager.sharedInstance.inspectingApp != nil else {
            return
        }
        let items = LKStaticHierarchyDataSource.sharedInstance.displayingFlatItems
        if items.isEmpty {
            return
        }
        let newTasks = makeMinimumTasks(for: items)
        if newTasks.isEmpty {
            return
        }
        send(newTasks, completion: nil)
    }

    private func send(_ newTasks: [LookinStaticAsyncUpdateTask], completion completionBlock: (() -> Void)?) {
        guard let app = LKAppsManager.sharedInstance.inspectingApp, !newTasks.isEmpty else {
            return
        }
        // 相同请求不能并发，因此必须先把之前的请求先取消掉
        endUpdating()

        let packages = makePackages(from: newTasks)
        let request = LKDetailUpdateRequest()
        request.packages = packages
        ongoingRequest = request

        notifyTasksCountToDelegate()

        NSLog("AsyncUpdate - Will send %@ tasks.", NSNumber(value: newTasks.count))

        app.fetchHierarchyDetail(withTaskPackages: packages, next: { [weak self] value in
            guard let self else { return }
            let details = (value as? [Any])?.compactMap { $0 as? LookinDisplayItemDetail } ?? []
            for detail in details {
                if detail.failureCode == -1 {
                    self.ongoingRequest?.failedTasksCount += 1
                } else {
                    LKStaticHierarchyDataSource.sharedInstance.modify(with: detail)
                }
            }
            self.ongoingRequest?.finishedTasksCount += details.count
            self.notifyTasksCountToDelegate()

        }, failure: { [weak self] _ in
            guard let self else { return }
            self.ongoingRequest = nil
            self.notifyTasksCountToDelegate()

            let msgTitle = NSLocalizedString("Request timeout, layer data transmission failed.", comment: "")
            let msgDetail = NSLocalizedString("Perhaps your iOS app is paused with breakpoint in Xcode, blocked by other tasks in main thread, or moved to background state.\nToo large screenshots may also lead to this error.", comment: "")
            let error = LookinError.make(msgTitle, msgDetail)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                // 此时可能 StaticViewController 还没来得及被初始化导致错误 tips 显示不出来，所以稍等一下
                self.delegate?.detailUpdateReceivedError(error)
            }

        }, completion: { [weak self] in
            // 注意，用户手动取消请求后，也会走到这里
            guard let self else { return }
            if let ongoingRequest = self.ongoingRequest {
                let userCancel = ongoingRequest.tasksTotalCount > ongoingRequest.finishedTasksCount
                if !userCancel {
                    self.succeededRequests.append(ongoingRequest)
                }

                if ongoingRequest.failedTasksCount > 0 {
                    let error = LookinError.make(NSLocalizedString("Some layer data failed to transmit.", comment: ""), NSLocalizedString("It may be due to changes in the layer structure within the iOS app. You can try reloading the entire structure in Lookin.", comment: ""))
                    self.delegate?.detailUpdateReceivedError(error)
                }

                self.ongoingRequest = nil
            } else {
                assertionFailure()
            }
            self.notifyTasksCountToDelegate()

            completionBlock?()
        })
    }

    func notifyTasksCountToDelegate() {
        let totalCount = ongoingRequest?.tasksTotalCount ?? 0
        let finishedCount = ongoingRequest?.finishedTasksCount ?? 0
        NSLog("AsyncUpdate - notify delagate: %@/%@", NSNumber(value: finishedCount), NSNumber(value: totalCount))
        delegate?.detailUpdateTasks(totalCount: totalCount, finishedCount: finishedCount)
    }

    /// 重新拉取一个 displayItem 的数据（图像+Attr），不包括子图层
    func reloadSingleDisplayItem(_ item: LookinDisplayItem) {
        guard let tasks = LKReloadSingleItemUpdateTaskMaker.make(with: item), !tasks.isEmpty else {
            return
        }
        send(tasks, completion: nil)
    }

    func reloadDisplayItemAndChildren(_ rootItem: LookinDisplayItem) {
        // 先更新 rootItem 的 basis + attr + subitems
        guard let tasks = LKReloadItemAndChildrenUpdateTaskMaker.make(with: rootItem), !tasks.isEmpty else {
            return
        }
        rootItem.enumerateSelfAndChildren { item in
            // 把 screenshots 以及完成的任务记录都删掉，因为稍后我们要重新拉取
            // 虽然待会儿返回的新 children 是新的 displayItem 实例，但新的 displayItem 实例的 oid 很可能没有变化，而 task 的 equal 是根据 oid 来计算的
            item.soloScreenshot = nil
            item.groupScreenshot = nil
            succeededRequests.forEach { $0.removeTask(with: item) }
        }

        send(tasks) {
            // 更新 rootItem 以及 children 的图层详情
            self.updateAfterReloadingItemAndChildren(rootItem)
        }
    }

    private func updateAfterReloadingItemAndChildren(_ rootItem: LookinDisplayItem) {
        // 拉取 rootItem 以及 children 的 screenshots + attr
        if LKPreferenceManager.mainManager.fastMode.currentBOOLValue {
            updateForDisplayingItems()
        } else {
            var tasks: [LookinStaticAsyncUpdateTask] = []
            rootItem.enumerateSelfAndChildren { item in
                if item.isUserCustom {
                    return
                }
                if item.doNotFetchScreenshotReason == .fetchScreenshotPermitted {
                    tasks.append(task(from: item, type: .groupScreenshot))
                    if item.isExpandable {
                        tasks.append(task(from: item, type: .soloScreenshot))
                    }
                } else {
                    tasks.append(task(from: item, type: .noScreenshot))
                }
            }
            send(tasks, completion: nil)
        }
    }
}
