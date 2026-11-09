//
//  SPLKAppsManager.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/3.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import Combine
import SPLKServer

let SPLKInspectingAppDidEndNotificationName = Notification.Name("SPLKInspectingAppDidEndNotificationName")

final class SPLKAppsManager {

    static let sharedInstance = SPLKAppsManager()

    private var storedInspectingApp: SPLKInspectableApp?
    private lazy var inspectingAppObservation = SPLKKVOSubject { [unowned self] in self.storedInspectingApp }

    var inspectingApp: SPLKInspectableApp? {
        get {
            storedInspectingApp
        }
        set {
            let shouldPostNotification = storedInspectingApp != nil && newValue == nil

            storedInspectingApp = newValue
            if let newValue {
                willConnectToApp.send(newValue)
            }

            if shouldPostNotification {
                NotificationCenter.default.post(name: SPLKInspectingAppDidEndNotificationName, object: self)
            }
            inspectingAppObservation.notify()
        }
    }

    /// Emits the current inspecting app on subscription and after every assignment, as RACObserve did.
    var inspectingAppPublisher: AnyPublisher<SPLKInspectableApp?, Never> {
        inspectingAppObservation.publisher
    }

    /// 断开后自动重连成功
    let didAutoReconnectSucc = PassthroughSubject<SPLKInspectableApp, Never>()

    private let willConnectToApp = PassthroughSubject<SPLKInspectableApp, Never>()
    private var cancellables = Set<AnyCancellable>()

    private init() {
        SPLKConnectionManager.sharedInstance.channelWillEnd
            .filter { [unowned self] channel in
                channel === self.inspectingApp?.channel
            }
            .sink { [unowned self] _ in
                NSLog("current connection end")
                let targetAppInfo = self.inspectingApp?.appInfo
                self.inspectingApp = nil
                self.startReconnecting(to: targetAppInfo)
            }
            .store(in: &cancellables)
    }

    /// Every 3 seconds, until another app becomes the inspecting app, look for an app like the one that disconnected.
    /// Lookups don't wait for each other, and one still in flight when the timer stops can still reconnect.
    private func startReconnecting(to targetAppInfo: SPLKAppInfo?) {
        let loop = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if Task.isCancelled {
                    break
                }
                Task {
                    if let newApp = await self.fetchInspectableApp(withSimilarInfo: targetAppInfo) {
                        NSLog("Reconnected successfully.")
                        self.inspectingApp = newApp
                        self.didAutoReconnectSucc.send(newApp)
                    }
                }
            }
        }
        willConnectToApp.first()
            .sink { _ in loop.cancel() }
            .store(in: &cancellables)
    }

    private func fetchInspectableApp(withSimilarInfo appInfo: SPLKAppInfo?) async -> SPLKInspectableApp? {
        let allApps = await fetchAppInfos(withImage: false, localInfos: nil)
        let targetApp = allApps.first { app in
            guard let appInfo, let otherInfo = app.appInfo else { return false }
            return appInfo.isEqual(to: otherInfo)
        }
        targetApp?.appInfo?.appIcon = appInfo?.appIcon
        return targetApp
    }

    /// 获取当前所有可查看的 iOS app
    /// needImages 是否需要返回截图和图标，不需要则可加快速度
    /// localInfos 本地已经存在的 appInfos，传入该参数从而可增量更新
    func fetchAppInfos(withImage needImages: Bool, localInfos: [SPLKAppInfo]?) async -> [SPLKInspectableApp] {
        let validAppInfos = (localInfos ?? []).filter { info in
            // 超过 8 秒则认为过期
            Date().timeIntervalSince1970 - info.cachedTimestamp <= 8
        }

        let localInfoIdentifiers = validAppInfos.map { NSNumber(value: $0.appInfoIdentifier) }
        let params: NSDictionary = ["needImages": NSNumber(value: needImages), "local": localInfoIdentifiers]

        let connectedChannels = await SPLKConnectionManager.sharedInstance.tryToConnectAllPorts()
        if connectedChannels.isEmpty {
            // 没有任何 channel
            return []
        }

        // Requests go out to every channel at once; results keep channel order, as RAC's zip did.
        let streams = connectedChannels.map { channel in
            SPLKConnectionManager.sharedInstance.request(type: UInt32(SPLKRequestTypeApp), data: params, channel: channel)
        }
        var apps: [SPLKInspectableApp] = []
        for stream in streams {
            do {
                // for-await stays on the main actor, where a hand-held iterator would have to be sent off it
                var firstElement: (SPLKConnectionResponseAttachment?, SPLK_PTChannel)?
                for try await element in stream {
                    firstElement = element
                    break
                }
                guard let (response, relatedChannel) = firstElement else {
                    continue
                }
                if response?.error != nil {
                    assertionFailure()
                    continue
                }
                guard var receivedInfo = response?.data as? SPLKAppInfo else {
                    continue
                }
                receivedInfo.cachedTimestamp = Date().timeIntervalSince1970
                if receivedInfo.shouldUseCache {
                    // 使用之前拉取的旧 info
                    if let localInfo = validAppInfos.first(where: { $0.appInfoIdentifier == receivedInfo.appInfoIdentifier }) {
                        receivedInfo = localInfo
                    }
                }

                let app = SPLKInspectableApp()
                app.appInfo = receivedInfo
                app.channel = relatedChannel
                apps.append(app)
            } catch {
                let code = (error as NSError).code
                if code == SPLKErrCode_ServerVersionTooHigh || code == SPLKErrCode_ServerVersionTooLow {
                    // 这些 Lookin 版本不匹配的错误应该被保留，因为业务需要显示这些错误
                    let app = SPLKInspectableApp()
                    app.serverVersionError = error as NSError
                    apps.append(app)
                }
                // 位于后台无法执行代码的 channel 会走到这里，应该过滤掉这些 channel
            }
        }
        return apps
    }
}
