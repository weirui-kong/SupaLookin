//
//  SPLKConnectionManager.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/2.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import Combine
import SPLKProtocol
import SPLKServer

enum SPLKDiscovery {
    case app(SPLKDeviceSession)
    case versionError(NSError)
}

/**
 iOS 是 Server 端，macOS 是 Client 端

 - 把 app 退到后台不会 kill 掉 server channel，仍旧会占用着端口（但可能无法执行代码）
 - 把 app kill 掉后，server channel 也会被 kill，端口占用会被释放

 - 一台电脑上的所有模拟器里的所有 app 共享同一批端口（在 SPLKServer 里是 47264 ～ 47269 这 6 个），比如依次启动“模拟器 A 的 app1”、“模拟器 A 的 app2”、“模拟器 B 的 app3”，则它们依次会占用 47264、47265、47266 这几个端口
 - 一台真机上的所有 app 共享同一批端口（在 SPLKServer 里是 47275 ~ 47279 这 5 个），比如依次启动“真机 A 的 app1”、“真机 A 的 app2”、“真机 B 的 app3”，则它们依次会占用 47275、47276、47275（注意不是 47277）这几个端口
 */
final class SPLKConnectionManager {

    static let sharedInstance = SPLKConnectionManager()

    /// 某个 session 结束了，一般是因为 server 端断开（比如 iOS app 被 kill 掉或 USB 被拔掉）
    let sessionDidEnd = PassthroughSubject<SPLKDeviceSession, Never>()

    private enum Port: Hashable {
        case simulator(UInt16)
        case usb(deviceID: NSNumber, port: UInt16)
    }

    private enum Outcome: Sendable {
        case client(SPLKClientSession)
        case versionError(Int)
        case unreachable
    }

    private var sessions: [Port: SPLKDeviceSession] = [:]
    private var usbDeviceIDs: [NSNumber] = []

    private init() {
        startListeningForUSBDevices()
    }

    // MARK: - Ports Connect

    /// 尝试连接所有可能的 Simulator 和 USB 端口，返回所有成功连接的 app（虽然成功连接但是 app 可能在后台之类的无法执行代码）
    /// A port that already has a session keeps it: connecting again would replace that session on the iOS side.
    func tryToConnectAllPorts() async -> [SPLKDiscovery] {
        var ports = (UInt16(SPLKSimulatorIPv4PortNumberStart)...UInt16(SPLKSimulatorIPv4PortNumberEnd)).map(Port.simulator)
        for deviceID in usbDeviceIDs {
            ports += (UInt16(SPLKUSBDeviceIPv4PortNumberStart)...UInt16(SPLKUSBDeviceIPv4PortNumberEnd)).map { Port.usb(deviceID: deviceID, port: $0) }
        }
        let attempts = ports.map { port in
            (port, sessions[port] == nil ? Task.detached { await Self.connect(port) } : nil)
        }
        var discoveries: [SPLKDiscovery] = []
        for (port, attempt) in attempts {
            if let session = sessions[port] {
                discoveries.append(.app(session))
                continue
            }
            switch await attempt?.value {
            case .client(let client):
                let session = SPLKDeviceSession(client: client)
                sessions[port] = session
                Task {
                    await session.waitUntilClosed()
                    self.sessionEnded(session, on: port)
                }
                discoveries.append(.app(session))
            case .versionError(let code):
                discoveries.append(.versionError(Self.versionError(code: code)))
            case .unreachable, nil:
                break
            }
        }
        return discoveries
    }

    private func sessionEnded(_ session: SPLKDeviceSession, on port: Port) {
        if sessions[port] === session {
            sessions[port] = nil
        }
        sessionDidEnd.send(session)
    }

    nonisolated private static func connect(_ port: Port) async -> Outcome {
        do {
            let client = try await SPLKClientSession.connect(configuration: SPLKDeviceSession.configuration) { _ in
                switch port {
                case .simulator(let number):
                    return try await SPLKNetworkByteStream.connect(host: "127.0.0.1", port: number, timeout: 0.5)
                case .usb(let deviceID, let number):
                    return try await openUSB(deviceID: deviceID, port: number)
                }
            }
            return .client(client)
        } catch SPLKHandshakeError.noServerHello {
            // Something accepted the connection but never said hello: a v1 SPLKServer.
            return .versionError(SPLKErrCode_ServerVersionTooLow)
        } catch SPLKHandshakeError.generationMismatch(let generation) {
            return .versionError(generation < SPLKProtocolInfo.generation ? SPLKErrCode_ServerVersionTooLow : SPLKErrCode_ServerVersionTooHigh)
        } catch {
            return .unreachable
        }
    }

    nonisolated private static func openUSB(deviceID: NSNumber, port: UInt16) async throws -> any SPLKByteStream {
        try await withCheckedThrowingContinuation { continuation in
            SPLK_PTUSBHub.shared().connect(toDevice: deviceID, port: Int32(port), onStart: { error, channel in
                if let error {
                    continuation.resume(throwing: error)
                } else if let channel {
                    continuation.resume(returning: SPLKDispatchIOByteStream(channel: channel))
                } else {
                    continuation.resume(throwing: SPLKTransportError.closed)
                }
            }, onEnd: nil)
        }
    }

    private static func versionError(code: Int) -> NSError {
        if code == SPLKErrCode_ServerVersionTooHigh {
            // server 版本过高，需要升级 client
            return NSError(domain: SPLKErrorDomain, code: SPLKErrCode_ServerVersionTooHigh, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Lookin app version is too low.", comment: ""),
                NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString("Target iOS app is linked with a higher version of SPLKServer. Please click \"Supa Lookin\"-\"Check for Updates\" near the top-left corner to update Supa Lookin.", comment: ""),
            ])
        }
        // server 版本过低，需要升级 server
        return NSError(domain: SPLKErrorDomain, code: SPLKErrCode_ServerVersionTooLow, userInfo: [
            NSLocalizedDescriptionKey: NSLocalizedString("Fail to inspect this iOS app due to a version problem.", comment: ""),
            NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString("Please update the SPLKServer package linked with target iOS App to a newer version.", comment: ""),
        ])
    }

    // MARK: - USB

    private func startListeningForUSBDevices() {
        let nc = NotificationCenter.default

        nc.addObserver(forName: .SPLK_PTUSBDeviceDidAttach, object: SPLK_PTUSBHub.shared(), queue: nil) { note in
            let deviceID = note.userInfo?["DeviceID"] as? NSNumber
            MainActor.assumeIsolated {
                // 仅一台真机 device 上的所有 app 共享同一批端口（在 SPLKServer 里是 47275 ~ 47279 这 5 个），不同真机互不影响。比如依次启动“真机 A 的 app1”、“真机 A 的 app2”、“真机 B 的 app3”，则它们依次会占用 47275、47276、47275（注意不是 47277）这几个端口
                if let deviceID {
                    SPLKConnectionManager.sharedInstance.usbDeviceIDs.append(deviceID)
                }
                NSLog("Lookin - USB 设备插入，DeviceID: %@", String(describing: deviceID))
            }
        }

        nc.addObserver(forName: .SPLK_PTUSBDeviceDidDetach, object: SPLK_PTUSBHub.shared(), queue: nil) { note in
            let deviceID = note.userInfo?["DeviceID"] as? NSNumber
            MainActor.assumeIsolated {
                SPLKConnectionManager.sharedInstance.usbDeviceIDs.removeAll { $0 == deviceID }
                NSLog("Lookin - USB 设备拔出，DeviceID: %@", String(describing: deviceID))
            }
        }
    }
}
