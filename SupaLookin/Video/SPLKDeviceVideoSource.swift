//
//  SPLKDeviceVideoSource.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import AVFoundation
import CoreMediaIO

// Captures a USB device's screen the way QuickTime's device mirroring does.
final class SPLKDeviceVideoSource: SPLKVideoSource {

    let serialNumber: String?

    private var capture: SPLKDeviceCapture?

    override var firstFrameTimeout: TimeInterval { 15 }

    init(serialNumber: String?) {
        self.serialNumber = serialNumber
    }

    override func startCapture() async throws {
        guard let serialNumber, !serialNumber.isEmpty else {
            throw SPLKVideoError(NSLocalizedString("The device's serial number is unknown.", comment: ""))
        }
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            throw SPLKVideoError(NSLocalizedString("Supa Lookin can't use the camera.", comment: ""), NSLocalizedString("Mirroring a device's screen counts as camera use. Allow Supa Lookin in System Settings > Privacy & Security > Camera.", comment: ""))
        }
        Self.allowScreenCaptureDevices()
        let device = try await Self.waitForDevice(serialNumber: serialNumber, timeout: 10)
        let capture = try SPLKDeviceCapture(device: device) { [weak self] buffer in
            self?.publish(buffer)
        }
        self.capture = capture
        await capture.start()
    }

    override func stopCapture() {
        capture?.stop()
        capture = nil
    }

    // Without this, iOS devices' screens never appear as capture devices.
    private static let allowed: Void = {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var allow: UInt32 = 1
        CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &allow)
    }()

    private static func allowScreenCaptureDevices() {
        _ = allowed
    }

    // usbmuxd reports serial numbers with a dash on newer devices; capture devices may drop it.
    nonisolated static func matches(uniqueID: String, serialNumber: String) -> Bool {
        let normalize = { (value: String) in value.replacingOccurrences(of: "-", with: "").lowercased() }
        return !serialNumber.isEmpty && normalize(uniqueID) == normalize(serialNumber)
    }

    // macOS 27 gives iOS screens a random uniqueID, so the phone's name is the link when its UDID isn't;
    // with one iOS screen attached there's nothing to confuse.
    nonisolated static func choose(_ screens: [(uniqueID: String, name: String)], serialNumber: String, deviceName: String?) -> Int? {
        if let index = screens.firstIndex(where: { matches(uniqueID: $0.uniqueID, serialNumber: serialNumber) }) {
            return index
        }
        if let deviceName, let index = screens.firstIndex(where: { $0.name == deviceName }) {
            return index
        }
        return screens.count == 1 ? 0 : nil
    }

    private static func currentDevice(serialNumber: String, deviceName: String?) -> AVCaptureDevice? {
        let screens = AVCaptureDevice.DiscoverySession(deviceTypes: [.external], mediaType: .muxed, position: .unspecified).devices
        return choose(screens.map { ($0.uniqueID, $0.localizedName) }, serialNumber: serialNumber, deviceName: deviceName).map { screens[$0] }
    }

    // The capture device appears a few seconds after screen capture devices are allowed.
    private static func waitForDevice(serialNumber: String, timeout: TimeInterval) async throws -> AVCaptureDevice {
        let deviceName = await Task.detached { Self.deviceName(udid: serialNumber) }.value
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let device = currentDevice(serialNumber: serialNumber, deviceName: deviceName) {
                return device
            }
            try await Task.sleep(for: .milliseconds(250))
        }
        throw SPLKVideoError(NSLocalizedString("The device's screen didn't appear.", comment: ""), NSLocalizedString("Unlock the device and make sure it trusts this Mac.", comment: ""))
    }

    // The name CoreDevice knows the phone by, which its capture device shares.
    nonisolated static func deviceName(udid: String) -> String? {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("splk-devices-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: output) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["devicectl", "list", "devices", "--quiet", "--json-output", output.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard let data = try? Data(contentsOf: output),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = (json["result"] as? [String: Any])?["devices"] as? [[String: Any]] else {
            return nil
        }
        let device = devices.first { (($0["hardwareProperties"] as? [String: Any])?["udid"] as? String)?.caseInsensitiveCompare(udid) == .orderedSame }
        return (device?["deviceProperties"] as? [String: Any])?["name"] as? String
    }
}

// Owns the capture session and its queue, off the main actor.
nonisolated final class SPLKDeviceCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "SPLKDeviceCapture")
    private let onFrame: @MainActor (CVPixelBuffer) -> Void

    init(device: AVCaptureDevice, onFrame: @escaping @MainActor (CVPixelBuffer) -> Void) throws {
        self.onFrame = onFrame
        super.init()
        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        session.beginConfiguration()
        guard session.canAddInput(input), session.canAddOutput(output) else {
            session.commitConfiguration()
            throw SPLKVideoError(NSLocalizedString("Failed to capture the device's screen.", comment: ""))
        }
        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()
    }

    // startRunning blocks until capture starts.
    func start() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.session.startRunning()
                continuation.resume()
            }
        }
    }

    func stop() {
        queue.async {
            self.session.stopRunning()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let frame = SPLKUncheckedPixelBuffer(buffer: buffer)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.onFrame(frame.buffer)
            }
        }
    }
}

// The capture output hands each buffer over and never touches it again.
private nonisolated struct SPLKUncheckedPixelBuffer: @unchecked Sendable {
    let buffer: CVPixelBuffer
}
