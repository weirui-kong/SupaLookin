//
//  SPLKMobileDeviceAFC.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/18.
//

import Foundation

// Writes a file into a paired device's media folder over AFC, through MobileDevice.framework (private). Only a host the
// device is paired with can start AFC, which is what makes splkhidd's token prove the client is that host.
nonisolated enum SPLKMobileDeviceAFC {

    private typealias DeviceRef = UnsafeMutableRawPointer
    private typealias NotificationCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void

    private final class Functions: @unchecked Sendable {
        let subscribe: @convention(c) (NotificationCallback, UInt32, UInt32, UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> Int32
        let unsubscribe: @convention(c) (UnsafeMutableRawPointer?) -> Int32
        let copyIdentifier: @convention(c) (DeviceRef) -> Unmanaged<CFString>?
        let connect: @convention(c) (DeviceRef) -> Int32
        let validatePairing: @convention(c) (DeviceRef) -> Int32
        let startSession: @convention(c) (DeviceRef) -> Int32
        let stopSession: @convention(c) (DeviceRef) -> Int32
        let disconnect: @convention(c) (DeviceRef) -> Int32
        let startService: @convention(c) (DeviceRef, CFString, CFDictionary?, UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> Int32
        let serviceSocket: @convention(c) (UnsafeMutableRawPointer) -> Int32
        let serviceSecureContext: @convention(c) (UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?
        let serviceInvalidate: @convention(c) (UnsafeMutableRawPointer) -> Void
        let afcOpen: @convention(c) (Int32, UInt32, UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> Int32
        let afcSetSecureContext: @convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Int32
        let afcDirectoryCreate: @convention(c) (UnsafeMutableRawPointer, UnsafePointer<CChar>) -> Int32
        let afcFileOpen: @convention(c) (UnsafeMutableRawPointer, UnsafePointer<CChar>, UInt64, UnsafeMutablePointer<UInt64>) -> Int32
        let afcFileWrite: @convention(c) (UnsafeMutableRawPointer, UInt64, UnsafeRawPointer, UInt32) -> Int32
        let afcFileClose: @convention(c) (UnsafeMutableRawPointer, UInt64) -> Int32
        let afcClose: @convention(c) (UnsafeMutableRawPointer) -> Int32

        init?() {
            guard let handle = dlopen("/Library/Apple/System/Library/PrivateFrameworks/MobileDevice.framework/MobileDevice", RTLD_NOW) else {
                return nil
            }
            func load<T>(_ name: String, as type: T.Type) -> T? {
                dlsym(handle, name).map { unsafeBitCast($0, to: type) }
            }
            guard let subscribe = load("AMDeviceNotificationSubscribe", as: (@convention(c) (NotificationCallback, UInt32, UInt32, UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> Int32).self),
                  let unsubscribe = load("AMDeviceNotificationUnsubscribe", as: (@convention(c) (UnsafeMutableRawPointer?) -> Int32).self),
                  let copyIdentifier = load("AMDeviceCopyDeviceIdentifier", as: (@convention(c) (DeviceRef) -> Unmanaged<CFString>?).self),
                  let connect = load("AMDeviceConnect", as: (@convention(c) (DeviceRef) -> Int32).self),
                  let validatePairing = load("AMDeviceValidatePairing", as: (@convention(c) (DeviceRef) -> Int32).self),
                  let startSession = load("AMDeviceStartSession", as: (@convention(c) (DeviceRef) -> Int32).self),
                  let stopSession = load("AMDeviceStopSession", as: (@convention(c) (DeviceRef) -> Int32).self),
                  let disconnect = load("AMDeviceDisconnect", as: (@convention(c) (DeviceRef) -> Int32).self),
                  let startService = load("AMDeviceSecureStartService", as: (@convention(c) (DeviceRef, CFString, CFDictionary?, UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> Int32).self),
                  let serviceSocket = load("AMDServiceConnectionGetSocket", as: (@convention(c) (UnsafeMutableRawPointer) -> Int32).self),
                  let serviceSecureContext = load("AMDServiceConnectionGetSecureIOContext", as: (@convention(c) (UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?).self),
                  let serviceInvalidate = load("AMDServiceConnectionInvalidate", as: (@convention(c) (UnsafeMutableRawPointer) -> Void).self),
                  let afcOpen = load("AFCConnectionOpen", as: (@convention(c) (Int32, UInt32, UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> Int32).self),
                  let afcSetSecureContext = load("AFCConnectionSetSecureContext", as: (@convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Int32).self),
                  let afcDirectoryCreate = load("AFCDirectoryCreate", as: (@convention(c) (UnsafeMutableRawPointer, UnsafePointer<CChar>) -> Int32).self),
                  let afcFileOpen = load("AFCFileRefOpen", as: (@convention(c) (UnsafeMutableRawPointer, UnsafePointer<CChar>, UInt64, UnsafeMutablePointer<UInt64>) -> Int32).self),
                  let afcFileWrite = load("AFCFileRefWrite", as: (@convention(c) (UnsafeMutableRawPointer, UInt64, UnsafeRawPointer, UInt32) -> Int32).self),
                  let afcFileClose = load("AFCFileRefClose", as: (@convention(c) (UnsafeMutableRawPointer, UInt64) -> Int32).self),
                  let afcClose = load("AFCConnectionClose", as: (@convention(c) (UnsafeMutableRawPointer) -> Int32).self) else {
                return nil
            }
            self.subscribe = subscribe
            self.unsubscribe = unsubscribe
            self.copyIdentifier = copyIdentifier
            self.connect = connect
            self.validatePairing = validatePairing
            self.startSession = startSession
            self.stopSession = stopSession
            self.disconnect = disconnect
            self.startService = startService
            self.serviceSocket = serviceSocket
            self.serviceSecureContext = serviceSecureContext
            self.serviceInvalidate = serviceInvalidate
            self.afcOpen = afcOpen
            self.afcSetSecureContext = afcSetSecureContext
            self.afcDirectoryCreate = afcDirectoryCreate
            self.afcFileOpen = afcFileOpen
            self.afcFileWrite = afcFileWrite
            self.afcFileClose = afcFileClose
            self.afcClose = afcClose
        }
    }

    private static let functions = Functions()

    private final class Search {
        let functions: Functions
        let udid: String
        var device: DeviceRef?

        init(functions: Functions, udid: String) {
            self.functions = functions
            self.udid = udid
        }
    }

    // AFC's write-only mode, which creates or truncates the file.
    private static let writeOnly: UInt64 = 3

    static func write(_ contents: Data, toDirectory directory: String, file: String, udid: String, timeout: TimeInterval = 5) async throws {
        guard let functions else {
            throw SPLKVideoError(NSLocalizedString("MobileDevice.framework isn't available.", comment: ""))
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Device notifications arrive on the run loop of the thread that subscribes.
            let thread = Thread {
                do {
                    try perform(functions, contents: contents, directory: directory, file: file, udid: udid, timeout: timeout)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            thread.name = "SPLKMobileDeviceAFC"
            thread.start()
        }
    }

    private static func perform(_ functions: Functions, contents: Data, directory: String, file: String, udid: String, timeout: TimeInterval) throws {
        let search = Search(functions: functions, udid: udid)
        let context = Unmanaged.passRetained(search)
        defer { context.release() }
        var subscription: UnsafeMutableRawPointer?
        let callback: NotificationCallback = { info, context in
            guard let info, let context else { return }
            let search = Unmanaged<Search>.fromOpaque(context).takeUnretainedValue()
            let message = info.load(fromByteOffset: MemoryLayout<UnsafeMutableRawPointer>.size, as: UInt32.self)
            guard message == 1, search.device == nil, let device = info.load(as: DeviceRef?.self),
                  let identifier = search.functions.copyIdentifier(device)?.takeRetainedValue() as String?,
                  identifier.replacingOccurrences(of: "-", with: "").caseInsensitiveCompare(search.udid.replacingOccurrences(of: "-", with: "")) == .orderedSame else {
                return
            }
            search.device = device
        }
        guard functions.subscribe(callback, 0, 0, context.toOpaque(), &subscription) == 0 else {
            throw SPLKVideoError(NSLocalizedString("Can't list devices through MobileDevice.framework.", comment: ""))
        }
        let deadline = Date().addingTimeInterval(timeout)
        while search.device == nil && Date() < deadline {
            CFRunLoopRunInMode(.defaultMode, 0.1, true)
        }
        defer { _ = functions.unsubscribe(subscription) }
        guard let device = search.device else {
            throw SPLKVideoError(NSLocalizedString("The device isn't connected.", comment: ""))
        }

        guard functions.connect(device) == 0 else {
            throw SPLKVideoError(NSLocalizedString("Can't connect to the device.", comment: ""))
        }
        defer { _ = functions.disconnect(device) }
        guard functions.validatePairing(device) == 0, functions.startSession(device) == 0 else {
            throw SPLKVideoError(NSLocalizedString("This Mac isn't paired with the device.", comment: ""), NSLocalizedString("Unlock the device and tap Trust when it asks about this Mac.", comment: ""))
        }
        var service: UnsafeMutableRawPointer?
        let started = functions.startService(device, "com.apple.afc" as CFString, nil, &service)
        _ = functions.stopSession(device)
        guard started == 0, let service else {
            throw SPLKVideoError(NSLocalizedString("Can't reach the device's media folder.", comment: ""))
        }
        defer { functions.serviceInvalidate(service) }

        var afc: UnsafeMutableRawPointer?
        guard functions.afcOpen(functions.serviceSocket(service), 0, &afc) == 0, let afc else {
            throw SPLKVideoError(NSLocalizedString("Can't reach the device's media folder.", comment: ""))
        }
        defer { _ = functions.afcClose(afc) }
        if let secure = functions.serviceSecureContext(service) {
            _ = functions.afcSetSecureContext(afc, secure)
        }
        _ = functions.afcDirectoryCreate(afc, directory)
        var reference: UInt64 = 0
        guard functions.afcFileOpen(afc, "\(directory)/\(file)", writeOnly, &reference) == 0 else {
            throw SPLKVideoError(NSLocalizedString("Can't write to the device's media folder.", comment: ""))
        }
        let written = contents.withUnsafeBytes { buffer in
            functions.afcFileWrite(afc, reference, buffer.baseAddress!, UInt32(buffer.count))
        }
        _ = functions.afcFileClose(afc, reference)
        guard written == 0 else {
            throw SPLKVideoError(NSLocalizedString("Can't write to the device's media folder.", comment: ""))
        }
    }
}
