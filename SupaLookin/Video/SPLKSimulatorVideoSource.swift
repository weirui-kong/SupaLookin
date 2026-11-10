//
//  SPLKSimulatorVideoSource.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import CoreVideo
import IOSurface
import SPLKProtocol

// Reads a simulator's framebuffer through CoreSimulator (private), as Simulator.app did.
final class SPLKSimulatorVideoSource: SPLKVideoSource {

    let udid: String?
    let screen: SPLKV2ScreenInfo

    private var display: SPLKSimulatorDisplay?
    private var callbackID: NSUUID?
    private var pixelBuffer: CVPixelBuffer?

    init(udid: String?, screen: SPLKV2ScreenInfo) {
        self.udid = udid
        self.screen = screen
    }

    override func startCapture() async throws {
        let udid = self.udid
        let pixelSize = CGSize(width: screen.size.width * screen.scale, height: screen.size.height * screen.scale)
        // CoreSimulator answers over XPC, synchronously.
        let display = try await Task.detached { try SPLKSimulatorDisplay.find(udid: udid, pixelSize: pixelSize) }.value
        self.display = display
        try wrapFramebuffer()
        let callbackID = NSUUID()
        self.callbackID = callbackID
        display.registerCallbacks(id: callbackID, frame: { [weak self] in
            MainActor.assumeIsolated { self?.frameDidChange() }
        }, surfacesChanged: { [weak self] in
            MainActor.assumeIsolated { try? self?.wrapFramebuffer() }
        })
        // The simulator draws nothing while its screen is still; the current framebuffer is the first frame.
        frameDidChange()
    }

    override func stopCapture() {
        if let callbackID {
            display?.unregisterCallbacks(id: callbackID)
        }
        callbackID = nil
        display = nil
        pixelBuffer = nil
    }

    private func wrapFramebuffer() throws {
        guard let surface = display?.framebuffer() else {
            throw SPLKVideoError(NSLocalizedString("The simulator's screen has no framebuffer.", comment: ""))
        }
        var buffer: Unmanaged<CVPixelBuffer>?
        guard CVPixelBufferCreateWithIOSurface(nil, surface, [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA] as CFDictionary, &buffer) == kCVReturnSuccess, let buffer else {
            throw SPLKVideoError(NSLocalizedString("Failed to read the simulator's framebuffer.", comment: ""))
        }
        pixelBuffer = buffer.takeRetainedValue()
    }

    private func frameDidChange() {
        if let pixelBuffer, callbackID != nil {
            publish(pixelBuffer)
        }
    }
}

nonisolated struct SPLKSimulatorScreen: Equatable {
    let screenID: UInt32
    let screenType: UInt
    let pixelSize: CGSize

    // The display whose pixels match the app's screen in either orientation, else the main built-in panel.
    static func choose(_ screens: [SPLKSimulatorScreen], pixelSize: CGSize) -> SPLKSimulatorScreen? {
        let width = pixelSize.width.rounded(), height = pixelSize.height.rounded()
        if width > 0, height > 0, let match = screens.first(where: {
            ($0.pixelSize.width == width && $0.pixelSize.height == height) || ($0.pixelSize.width == height && $0.pixelSize.height == width)
        }) {
            return match
        }
        return screens.filter { $0.screenType == 0 }.min { $0.screenID < $1.screenID } ?? screens.first
    }
}

// CoreSimulator's objects are XPC proxies that raise for selectors they lack, which Swift can't catch, so every call checks first.
nonisolated final class SPLKSimulatorDisplay: @unchecked Sendable {

    private let descriptor: NSObject

    private init(descriptor: NSObject) {
        self.descriptor = descriptor
    }

    static func find(udid: String?, pixelSize: CGSize) throws -> SPLKSimulatorDisplay {
        let device = try bootedDevice(udid: udid)
        guard let io = object(device, "io"), let ports = object(io, "ioPorts") as? [NSObject] else {
            throw SPLKVideoError(NSLocalizedString("The simulator has no displays.", comment: ""))
        }
        var candidates: [(SPLKSimulatorScreen, NSObject)] = []
        for port in ports {
            guard let descriptor = object(port, "descriptor"),
                  let renderable = NSProtocolFromString("SimDisplayIOSurfaceRenderable"), descriptor.conforms(to: renderable),
                  let screenProtocol = NSProtocolFromString("SimScreen"), descriptor.conforms(to: screenProtocol),
                  object(descriptor, "framebufferSurface") != nil,
                  let properties = object(descriptor, "screenProperties") else {
                continue
            }
            let screen = SPLKSimulatorScreen(
                screenID: value(properties, "screenID", as: UInt32.self) ?? .max,
                screenType: value(properties, "screenType", as: UInt.self) ?? .max,
                pixelSize: value(properties, "pixelSize", as: CGSize.self) ?? .zero)
            candidates.append((screen, descriptor))
        }
        guard let chosen = SPLKSimulatorScreen.choose(candidates.map(\.0), pixelSize: pixelSize),
              let descriptor = candidates.first(where: { $0.0 == chosen })?.1 else {
            throw SPLKVideoError(NSLocalizedString("The simulator has no displays.", comment: ""))
        }
        return SPLKSimulatorDisplay(descriptor: descriptor)
    }

    func framebuffer() -> IOSurfaceRef? {
        guard let surface = Self.object(descriptor, "framebufferSurface") else {
            return nil
        }
        return unsafeBitCast(surface, to: IOSurfaceRef.self)
    }

    func registerCallbacks(id: NSUUID, frame: @escaping @convention(block) () -> Void, surfacesChanged: @escaping @convention(block) () -> Void) {
        let selector = NSSelectorFromString("registerScreenCallbacksWithUUID:callbackQueue:frameCallback:surfacesChangedCallback:propertiesChangedCallback:")
        guard descriptor.responds(to: selector) else {
            return
        }
        typealias Register = @convention(c) (NSObject, Selector, NSUUID, DispatchQueue, @convention(block) () -> Void, @convention(block) () -> Void, @convention(block) () -> Void) -> Void
        let register = unsafeBitCast(descriptor.method(for: selector), to: Register.self)
        register(descriptor, selector, id, .main, frame, surfacesChanged, {})
    }

    func unregisterCallbacks(id: NSUUID) {
        let selector = NSSelectorFromString("unregisterScreenCallbacksWithUUID:")
        guard descriptor.responds(to: selector) else {
            return
        }
        _ = descriptor.perform(selector, with: id)
    }

    // MARK: - CoreSimulator

    private static func bootedDevice(udid: String?) throws -> NSObject {
        let context = try serviceContext()
        var error: NSError?
        typealias DeviceSet = @convention(c) (NSObject, Selector, UnsafeMutablePointer<NSError?>?) -> NSObject?
        let selector = NSSelectorFromString("defaultDeviceSetWithError:")
        guard context.responds(to: selector),
              let set = unsafeBitCast(context.method(for: selector), to: DeviceSet.self)(context, selector, &error),
              let devices = object(set, "devices") as? [NSObject] else {
            throw SPLKVideoError(NSLocalizedString("Failed to list simulators.", comment: ""), error?.localizedDescription)
        }
        let booted = devices.filter { (object($0, "stateString") as? String) == "Booted" }
        let device: NSObject?
        if let udid {
            device = booted.first { (object($0, "UDID") as? NSUUID)?.uuidString.caseInsensitiveCompare(udid) == .orderedSame }
        } else {
            device = booted.count == 1 ? booted.first : nil
        }
        guard let device else {
            throw SPLKVideoError(NSLocalizedString("The app's simulator isn't booted.", comment: ""))
        }
        return device
    }

    // Loaded once; the context is thread-safe.
    nonisolated(unsafe) private static let contextResult: Result<NSObject, SPLKVideoError> = {
        guard dlopen("/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator", RTLD_NOW) != nil,
              let contextClass = NSClassFromString("SimServiceContext") as? NSObject.Type else {
            return .failure(SPLKVideoError(NSLocalizedString("CoreSimulator can't be loaded.", comment: ""), NSLocalizedString("Install Xcode and its simulator runtimes.", comment: "")))
        }
        let selector = NSSelectorFromString("sharedServiceContextForDeveloperDir:error:")
        guard contextClass.responds(to: selector) else {
            return .failure(SPLKVideoError(NSLocalizedString("CoreSimulator can't be loaded.", comment: ""), nil))
        }
        typealias SharedContext = @convention(c) (AnyClass, Selector, NSString, UnsafeMutablePointer<NSError?>?) -> NSObject?
        var error: NSError?
        let shared = unsafeBitCast(contextClass.method(for: selector), to: SharedContext.self)
        guard let context = shared(contextClass, selector, developerDirectory() as NSString, &error) else {
            return .failure(SPLKVideoError(NSLocalizedString("CoreSimulator can't be loaded.", comment: ""), error?.localizedDescription))
        }
        return .success(context)
    }()

    private static func serviceContext() throws -> NSObject {
        try contextResult.get()
    }

    private static func developerDirectory() -> String {
        if let directory = ProcessInfo.processInfo.environment["DEVELOPER_DIR"], !directory.isEmpty {
            return directory
        }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else {
            return "/Applications/Xcode.app/Contents/Developer"
        }
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let path = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? "/Applications/Xcode.app/Contents/Developer" : path
    }

    private static func object(_ target: NSObject, _ name: String) -> NSObject? {
        let selector = NSSelectorFromString(name)
        guard target.responds(to: selector) else {
            return nil
        }
        return target.perform(selector)?.takeUnretainedValue() as? NSObject
    }

    private static func value<T>(_ target: NSObject, _ name: String, as type: T.Type) -> T? {
        let selector = NSSelectorFromString(name)
        guard target.responds(to: selector) else {
            return nil
        }
        let implementation = target.method(for: selector)
        switch type {
        case is UInt32.Type:
            typealias Getter = @convention(c) (NSObject, Selector) -> UInt32
            return unsafeBitCast(implementation, to: Getter.self)(target, selector) as? T
        case is UInt.Type:
            typealias Getter = @convention(c) (NSObject, Selector) -> UInt
            return unsafeBitCast(implementation, to: Getter.self)(target, selector) as? T
        case is CGSize.Type:
            typealias Getter = @convention(c) (NSObject, Selector) -> CGSize
            return unsafeBitCast(implementation, to: Getter.self)(target, selector) as? T
        default:
            return nil
        }
    }
}
