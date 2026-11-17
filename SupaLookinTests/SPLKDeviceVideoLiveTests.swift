//
//  SPLKDeviceVideoLiveTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import Combine
import CoreVideo
import Testing
import SPLKProtocol
@testable import SupaLookin

// Captures a USB device's screen through CoreMediaIO. Run with TEST_RUNNER_SPLK_DEVICE_SERIAL set to the device's UDID;
// TEST_RUNNER_SPLK_DEVICE_OUT names a folder for the marker, frame counts and a snapshot, so another process can act while frames are counted.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["SPLK_DEVICE_SERIAL"] != nil))
struct SPLKDeviceVideoLiveTests {

    @Test func deviceScreenStreams() async throws {
        let environment = ProcessInfo.processInfo.environment
        let serial = try #require(environment["SPLK_DEVICE_SERIAL"])
        let folder = URL(fileURLWithPath: environment["SPLK_DEVICE_OUT"] ?? NSTemporaryDirectory())
        let source = SPLKDeviceVideoSource(serialNumber: serial)
        try await source.start()
        defer { source.stop() }

        var frames = 0
        let subscription = source.frames.compactMap { $0 }.sink { _ in frames += 1 }
        defer { subscription.cancel() }
        for _ in 0..<50 where source.frames.value == nil {
            try await Task.sleep(for: .milliseconds(100))
        }
        let first = try #require(source.frames.value)
        print("device video: \(CVPixelBufferGetWidth(first.pixelBuffer))x\(CVPixelBufferGetHeight(first.pixelBuffer))")

        try "streaming".write(to: folder.appendingPathComponent("streaming"), atomically: true, encoding: .utf8)
        var counts: [Int] = []
        for _ in 0..<3 {
            let start = frames
            try await Task.sleep(for: .seconds(4))
            counts.append(frames - start)
        }
        print("device video frames per 4 s window: \(counts)")
        try counts.map(String.init).joined(separator: " ").write(to: folder.appendingPathComponent("counts"), atomically: true, encoding: .utf8)
        #expect(counts.allSatisfy { $0 > 0 })

        var screen = SPLKV2ScreenInfo()
        screen.size.width = 375
        screen.size.height = 812
        let image = try await source.snapshot(screen: screen)
        if let png = SPLKMCPPayload.png(of: image) {
            try png.write(to: folder.appendingPathComponent("snapshot.png"))
        }
    }
}
