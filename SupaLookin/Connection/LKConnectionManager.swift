//
//  LKConnectionManager.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/2.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import Combine
import QuartzCore
@preconcurrency import LookinShared

/// The push frame types the client accepts. The Objective-C client declared none, so pushes are never delivered.
private let pushFrameTypeList = IndexSet()

/// Active requests live on the channel itself, as the Objective-C category's bound object did.
private final class LKActiveRequests {
    var requests: [LKConnectionRequest] = []
}

private extension Lookin_PTChannel {

    var activeRequests: LKActiveRequests? {
        get { lookin_getBindObject(forKey: "activeRequest") as? LKActiveRequests }
        set { lookin_bindObject(newValue, forKey: "activeRequest") }
    }
}

private final class LKSimulatorConnectionPort {
    var portNumber: Int32 = 0
    var connectedChannel: Lookin_PTChannel?
}

private final class LKUSBConnectionPort {
    var portNumber: Int32 = 0
    var deviceID: NSNumber?
    var connectedChannel: Lookin_PTChannel?
}

/**
 iOS 是 Server 端，macOS 是 Client 端

 - 把 app 退到后台不会 kill 掉 server channel，仍旧会占用着端口（但可能无法执行代码）
 - 把 app kill 掉后，server channel 也会被 kill，端口占用会被释放

 - 一台电脑上的所有模拟器里的所有 app 共享同一批端口（在 Lookin 里是 47164 ～ 47169 这 6 个），比如依次启动“模拟器 A 的 app1”、“模拟器 A 的 app2”、“模拟器 B 的 app3”，则它们依次会占用 47164、47165、47166 这几个端口
 - 一台真机上的所有 app 共享同一批端口（在 Lookin 里是 47175 ~ 47179 这 5 个），比如依次启动“真机 A 的 app1”、“真机 A 的 app2”、“真机 B 的 app3”，则它们依次会占用 47175、47176、47175（注意不是 47177）这几个端口
 */
final class LKConnectionManager: NSObject, @preconcurrency Lookin_PTChannelDelegate {

    static let sharedInstance = LKConnectionManager()

    /// 即将关闭某个 channel，一般是因为 server 端断开（比如 iOS app 被 kill 掉或 USB 被拔掉）
    let channelWillEnd = PassthroughSubject<Lookin_PTChannel, Never>()

    /// 收到了 server 端发送的 push 消息，分别为 channel, pushType, data
    let didReceivePush = PassthroughSubject<(Lookin_PTChannel, UInt32, Any?), Never>()

    private let allSimulatorPorts: [LKSimulatorConnectionPort]
    private var allUSBPorts: [LKUSBConnectionPort] = []

    private var receivedDataSize = 0
    private var receivingStartTime: CFTimeInterval = 0

    private override init() {
        allSimulatorPorts = (LookinSimulatorIPv4PortNumberStart...LookinSimulatorIPv4PortNumberEnd).map { number in
            let port = LKSimulatorConnectionPort()
            port.portNumber = number
            return port
        }
        super.init()

        startListeningForUSBDevices()

        LKServerVersionRequestor.shared.preload()
    }

    // MARK: - Ports Connect

    /// 尝试连接所有可能的 Simulator 和 USB 端口，返回所有成功连接的 Lookin_PTChannel（虽然成功连接但是 app 可能在后台之类的无法执行代码）
    func tryToConnectAllPorts() async -> [Lookin_PTChannel] {
        let box = await withCheckedContinuation { continuation in
            connectAll(simulatorPorts: allSimulatorPorts, usbPorts: allUSBPorts) { channels in
                continuation.resume(returning: ChannelsBox(channels: channels))
            }
        }
        return box.channels
    }

    private func connectAll(simulatorPorts: [LKSimulatorConnectionPort], usbPorts: [LKUSBConnectionPort], completion: @escaping ([Lookin_PTChannel]) -> Void) {
        let total = simulatorPorts.count + usbPorts.count
        var results = [Lookin_PTChannel?](repeating: nil, count: total)
        var remaining = total
        if total == 0 {
            completion([])
            return
        }
        let finish: (Int, Lookin_PTChannel?) -> Void = { index, channel in
            results[index] = channel
            remaining -= 1
            if remaining == 0 {
                completion(results.compactMap { $0 })
            }
        }
        for (idx, port) in simulatorPorts.enumerated() {
            connect(toSimulatorPort: port) { finish(idx, $0) }
        }
        for (idx, port) in usbPorts.enumerated() {
            connect(toUSBPort: port) { finish(simulatorPorts.count + idx, $0) }
        }
    }

    /// 注意，如果某个 app 被退到了后台但是没有被 kill，则在这个方法里它的 channel 仍然会被成功连接
    private func connect(toSimulatorPort port: LKSimulatorConnectionPort, completion: @escaping (Lookin_PTChannel?) -> Void) {
        if let channel = port.connectedChannel {
            // 该 port 本来就已经成功连接
            completion(channel)
            return
        }
        guard let localChannel = Lookin_PTChannel(delegate: self) else {
            completion(nil)
            return
        }
        // INADDR_LOOPBACK
        localChannel.connect(toPort: in_port_t(port.portNumber), iPv4Address: 0x7f000001) { error, _ in
            MainActor.assumeIsolated {
                if error != nil {
                    localChannel.close()
                    completion(nil)
                } else {
                    port.connectedChannel = localChannel
                    completion(localChannel)
                }
            }
        }
    }

    private func connect(toUSBPort port: LKUSBConnectionPort, completion: @escaping (Lookin_PTChannel?) -> Void) {
        if let channel = port.connectedChannel {
            // 该 port 本来就已经成功连接
            completion(channel)
            return
        }
        guard let channel = Lookin_PTChannel(delegate: self) else {
            completion(nil)
            return
        }
        channel.connect(toPort: port.portNumber, overUSBHub: Lookin_PTUSBHub.shared(), deviceID: port.deviceID) { error in
            MainActor.assumeIsolated {
                if error != nil {
                    channel.close()
                    completion(nil)
                } else {
                    // succ
                    port.connectedChannel = channel
                    completion(channel)
                }
            }
        }
    }

    // MARK: - Request

    /// 如果发送的消息不需要 server 端回复，则请使用该方法而非 request
    /// 如果此时 server 端不在前台或处于断点等模式，则 server 端可能无法收到该消息
    func push(type pushType: UInt32, data: Any?, channel: Lookin_PTChannel?) {
        guard let channel, channel.isConnected else {
            return
        }
        let payload = Self.archivedPayload(data)
        NSLog("LookinClient - pushData, type:%@", NSNumber(value: pushType))
        channel.sendFrame(ofType: pushType, tag: 0, withPayload: payload, callback: nil)
    }

    /// 每收到一份 response 就产出一个值，全部收到后结束
    /// 在调用该方法发请求时，如果已有相同 type 的旧 request 尚未返回结果，则之前的旧 request 会被报告 Error，然后被丢弃
    func request(type requestType: UInt32, data requestData: Any?, channel: Lookin_PTChannel) -> AsyncThrowingStream<(LookinConnectionResponseAttachment?, Lookin_PTChannel), Error> {
        AsyncThrowingStream { continuation in
            self.sendRequest(type: requestType, data: requestData, channel: channel, next: { response in
                continuation.yield((response, channel))
            }, fail: { error in
                continuation.finish(throwing: error)
            }, completion: {
                continuation.finish()
            })
        }
    }

    /// Pings first, then sends the request. `next` runs once per response, synchronously inside Peertalk's callback.
    func sendRequest(type requestType: UInt32, data requestData: Any?, channel: Lookin_PTChannel, next: @escaping (LookinConnectionResponseAttachment?) -> Void, fail: @escaping (Error) -> Void, completion: @escaping () -> Void) {
        let timeoutInterval: TimeInterval
        if requestType == LookinRequestTypeApp {
            // 如果某个 iOS app 连接上了 channel 却又处于后台的话，而这个 timeout 时间又过长的话，就会导致初次进入 launch 时非常慢（因为必须等到 timeoutInterval 结束），因此这里为了体验缩小这个时间
            timeoutInterval = 0.5
        } else {
            timeoutInterval = 2
        }

        request(type: UInt32(LookinRequestTypePing), channel: channel, data: nil, timeoutInterval: timeoutInterval, succ: { pingResponse in
            // ping 成功了
            if let versionErr = self.checkServerVersion(with: pingResponse) {
                // LookinServer 版本有问题
                fail(versionErr)
            } else {
                // 没问题，开始发真正请求
                self.request(type: requestType, channel: channel, data: requestData, timeoutInterval: 5, succ: next, fail: fail, completion: completion)
            }
        }, fail: { error in
            // ping 失败了
            fail(error)
        }, completion: nil)
    }

    private func checkServerVersion(with pingResponse: LookinConnectionResponseAttachment?) -> NSError? {
        let serverVersion = pingResponse?.lookinServerVersion ?? 0
        if serverVersion == -1 || serverVersion == 100 {
            // 说明用的还是旧版本的内部版本 LookinServer，这里兼容一下
            return Self.serverVersionTooLowError()
        }

        if serverVersion > LOOKIN_SUPPORTED_SERVER_MAX {
            // server 版本过高，需要升级 client
            return NSError(domain: LookinErrorDomain, code: LookinErrCode_ServerVersionTooHigh, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Lookin app version is too low.", comment: ""),
                NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString("Target iOS app is linked with a higher version LookinServer.framework. Please click \"Lookin\"-\"Check for Updates\" near the top-left corner or visit https://lookin.work to update your Lookin app.", comment: ""),
            ])
        }

        if serverVersion < LOOKIN_SUPPORTED_SERVER_MIN {
            // server 版本过低，需要升级 server
            return Self.serverVersionTooLowError()
        }

        return nil
    }

    private static func serverVersionTooLowError() -> NSError {
        NSError(domain: LookinErrorDomain, code: LookinErrCode_ServerVersionTooLow, userInfo: [
            NSLocalizedDescriptionKey: NSLocalizedString("Fail to inspect this iOS app due to a version problem.", comment: ""),
            NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString("Please update LookinServer.framework linked with target iOS App to a newer version. Visit the website below to get detailed instructions:\nhttps://lookin.work/faq/server-version-too-low/", comment: ""),
        ])
    }

    // MARK: - Private

    private func request(type requestType: UInt32, channel: Lookin_PTChannel, data: Any?, timeoutInterval: TimeInterval, succ succBlock: @escaping (LookinConnectionResponseAttachment?) -> Void, fail failBlock: @escaping (Error) -> Void, completion completionBlock: (() -> Void)?) {
        if !channel.isConnected {
            failBlock(LookinError.noConnect)
            return
        }
        if let active = channel.activeRequests, !active.requests.isEmpty, requestType != LookinRequestTypePing {
            // 检查是否有相同 type 的旧请求尚在进行中，如果有则移除之前的旧请求（旧请求会被报告 error）
            let requestsToBeDiscarded = active.requests.filter { $0.type == requestType }
            for obj in requestsToBeDiscarded {
                let error = NSError(domain: LookinErrorDomain, code: LookinErrCode_Discard, userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("The request is discarded due to a newer same request.", comment: ""),
                ])
                obj.failBlock?(error)
                obj.endTimeoutCount()
                active.requests.removeAll { $0 === obj }

                NSLog("LookinClient - will discard request, type:%@, tag:%@", NSNumber(value: obj.type), NSNumber(value: obj.tag))
            }
        }

        let request = LKConnectionRequest()
        request.type = requestType
        request.tag = UInt32(Date().timeIntervalSince1970)
        request.succBlock = succBlock
        request.failBlock = failBlock
        request.completionBlock = completionBlock
        request.timeoutInterval = timeoutInterval
        request.timeoutBlock = { [weak channel] selfRequest in
            let error = NSError(domain: LookinErrorDomain, code: LookinErrCode_Timeout, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Request timeout", comment: ""),
                NSLocalizedRecoverySuggestionErrorKey: LookinError.timeoutText,
            ])
            selfRequest.failBlock?(error)
            channel?.activeRequests?.requests.removeAll { $0 === selfRequest }
        }

        let attachment = LookinConnectionAttachment()
        attachment.data = data
        let payload = Self.archivedPayload(attachment)
        channel.sendFrame(ofType: requestType, tag: request.tag, withPayload: payload) { error in
            MainActor.assumeIsolated {
                if error != nil {
                    failBlock(NSError(domain: LookinErrorDomain, code: LookinErrCode_PeerTalk, userInfo: [
                        NSLocalizedDescriptionKey: NSLocalizedString("The operation failed due to an inner error.", comment: ""),
                    ]))
                } else {
                    // 成功发出了该 request
                    if channel.activeRequests == nil {
                        channel.activeRequests = LKActiveRequests()
                    }
                    channel.activeRequests?.requests.append(request)
                    request.resetTimeoutCount()
                }
            }
        }
    }

    private static func archivedPayload(_ object: Any?) -> __DispatchData? {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: object as Any, requiringSecureCoding: true)
            return (data as NSData).createReferencingDispatchData()
        } catch {
            assertionFailure()
            return nil
        }
    }

    /// 取消先前使用 request 方法发送的尚未完成的 request，这个 request 会被报告为 completion
    func cancelRequest(type requestType: UInt32, channel: Lookin_PTChannel?) {
        guard let channel, let activeRequest = channel.activeRequests?.requests.first(where: { $0.type == requestType }) else {
            return
        }
        activeRequest.endTimeoutCount()
        channel.activeRequests?.requests.removeAll { $0 === activeRequest }
        activeRequest.completionBlock?()
        NSLog("Lookin - 用户手动取消 request, type:%@", NSNumber(value: requestType))
    }

    private func startListeningForUSBDevices() {
        let nc = NotificationCenter.default

        nc.addObserver(forName: .Lookin_PTUSBDeviceDidAttach, object: Lookin_PTUSBHub.shared(), queue: nil) { note in
            let deviceID = note.userInfo?["DeviceID"] as? NSNumber
            MainActor.assumeIsolated {
                // 仅一台真机 device 上的所有 app 共享同一批端口（在 Lookin 里是 47175 ~ 47179 这 5 个），不同真机互不影响。比如依次启动“真机 A 的 app1”、“真机 A 的 app2”、“真机 B 的 app3”，则它们依次会占用 47175、47176、47175（注意不是 47177）这几个端口
                for number in LookinUSBDeviceIPv4PortNumberStart...LookinUSBDeviceIPv4PortNumberEnd {
                    let port = LKUSBConnectionPort()
                    port.portNumber = number
                    port.deviceID = deviceID
                    LKConnectionManager.sharedInstance.allUSBPorts.append(port)
                }
                NSLog("Lookin - USB 设备插入，DeviceID: %@", String(describing: deviceID))
            }
        }

        nc.addObserver(forName: .Lookin_PTUSBDeviceDidDetach, object: Lookin_PTUSBHub.shared(), queue: nil) { note in
            let deviceID = note.userInfo?["DeviceID"] as? NSNumber
            MainActor.assumeIsolated {
                LKConnectionManager.sharedInstance.allUSBPorts.removeAll { $0.deviceID == deviceID }
                NSLog("Lookin - USB 设备拔出，DeviceID: %@", String(describing: deviceID))
            }
        }
    }

    // MARK: - Lookin_PTChannelDelegate

    func ioFrameChannel(_ channel: Lookin_PTChannel, shouldAcceptFrameOfType type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
        if pushFrameTypeList.contains(Int(type)) {
            return true
        }
        if channel.activeRequests?.requests.contains(where: { $0.type == type && $0.tag == tag }) == true {
            return true
        }
        NSLog("LookinClient - will refuse, type:%@, tag:%@", NSNumber(value: type), NSNumber(value: tag))
        return false
    }

    func ioFrameChannel(_ channel: Lookin_PTChannel, didReceiveFrameOfType type: UInt32, tag: UInt32, payload: Lookin_PTData?) {
        if pushFrameTypeList.contains(Int(type)) {
            let data = payload.map { NSData(contentsOfDispatchData: $0.dispatchData) as Data } ?? Data()
            let unarchivedData = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSObject.self], from: data)
            didReceivePush.send((channel, type, unarchivedData))
            return
        }

        guard let activeRequest = channel.activeRequests?.requests.first(where: { $0.type == type && $0.tag == tag }) else {
            // 也许在 shouldAcceptFrameOfType 和 didReceiveFrame 两个时机之间，该 request 因为超时而被销毁了？有点玄学但确实偶尔会走到这里。
            return
        }
        let data = payload.map { NSData(contentsOfDispatchData: $0.dispatchData) as Data } ?? Data()
        var attachment: LookinConnectionResponseAttachment?
        do {
            attachment = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSObject.self], from: data) as? LookinConnectionResponseAttachment
        } catch {
            NSLog("Error:%@", String(describing: error))
        }

        if attachment?.appIsInBackground == true {
            // app 处于后台模式
            activeRequest.endTimeoutCount()
            channel.activeRequests?.requests.removeAll { $0 === activeRequest }
            activeRequest.failBlock?(NSError(domain: LookinErrorDomain, code: LookinErrCode_PingFailForBackgroundState, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("The operation failed because target iOS app has entered to the background state.", comment: ""),
            ]))
            NSLog("Lookin - iOS app 报告自己处于后台，request fail")
            return
        }

        activeRequest.succBlock?(attachment)

        if activeRequest.receivedDataCount == 0 {
            receivedDataSize = 0
            receivingStartTime = CACurrentMediaTime()
        }
        receivedDataSize += data.count

        var hasReceivedAllResponses = false
        let dataTotalCount = attachment?.dataTotalCount ?? 0
        if dataTotalCount > 0 {
            activeRequest.receivedDataCount += attachment?.currentDataCount ?? 0
            if activeRequest.receivedDataCount >= dataTotalCount {
                hasReceivedAllResponses = true
            }
        } else {
            hasReceivedAllResponses = true
        }

        if hasReceivedAllResponses {
            activeRequest.endTimeoutCount()
            channel.activeRequests?.requests.removeAll { $0 === activeRequest }
            activeRequest.completionBlock?()

            let timeDuration = CACurrentMediaTime() - receivingStartTime
            let totalSize = Double(receivedDataSize) / 1024.0 / 1024.0
            if totalSize > 0.5 {
                NSLog("Lookin - %@", String(format: "已收到全部请求 %@ / %@，总耗时:%.2f, 数据总大小:%.2fM", NSNumber(value: activeRequest.receivedDataCount), NSNumber(value: dataTotalCount), timeDuration, totalSize))
            }
        } else {
            // 对于多 response 的请求，每收到一次 response 则重置 timeout 倒计时
            activeRequest.resetTimeoutCount()
        }
    }

    func ioFrameChannel(_ channel: Lookin_PTChannel, didEndWithError error: Error?) {
        // iOS 客户端断开
        for port in allSimulatorPorts where port.connectedChannel === channel {
            port.connectedChannel = nil
        }
        for port in allUSBPorts where port.connectedChannel === channel {
            port.connectedChannel = nil
        }
        channelWillEnd.send(channel)

        channel.close()
    }
}

// Peertalk calls back on the main queue and the result is awaited on the main actor, so the channels never cross threads.
private struct ChannelsBox: @unchecked Sendable {
    let channels: [Lookin_PTChannel]
}
