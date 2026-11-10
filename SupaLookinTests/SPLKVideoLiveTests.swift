//
//  SPLKVideoLiveTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import Combine
import Testing
import SPLKProtocol
import SPLKServer
@testable import SupaLookin

// Runs against the e2e demo on a booted simulator. Run with TEST_RUNNER_SPLK_VIDEO_E2E=1, apart from SPLKModesLiveTests since the demo serves one session at a time; TEST_RUNNER_SPLK_VIDEO_OUT names a PNG to write.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["SPLK_VIDEO_E2E"] == "1"))
struct SPLKVideoLiveTests {

    private func demoSession() async throws -> SPLKDeviceSession {
        // The test host is Supa Lookin, whose launch discovery would replace a session opened earlier.
        try await Task.sleep(for: .seconds(3))
        for port in UInt16(SPLKSimulatorIPv4PortNumberStart)...UInt16(SPLKSimulatorIPv4PortNumberEnd) {
            guard let client = try? await SPLKClientSession.connect(configuration: SPLKDeviceSession.configuration, open: { _ in
                try await SPLKNetworkByteStream.connect(host: "127.0.0.1", port: port, timeout: 1)
            }) else { continue }
            if client.serverHello.app.bundleIdentifier == "icu.retrouvailles.splkdemo" {
                return SPLKDeviceSession(client: client, target: .simulator(udid: client.serverHello.app.simulatorUdid))
            }
            await client.close()
        }
        throw SPLKVideoError("demo not found")
    }

    // Redraws the whole screen.
    private func setAppearance(_ udid: String, _ appearance: String) throws {
        let process = try Process.run(URL(fileURLWithPath: "/usr/bin/xcrun"), arguments: ["simctl", "ui", udid, "appearance", appearance])
        process.waitUntilExit()
    }

    @Test func simulatorVideoStreamsAndSnapshots() async throws {
        let session = try await demoSession()
        defer { Task { await session.close() } }
        guard case .simulator(let udid) = session.target else {
            Issue.record("not a simulator target")
            return
        }
        #expect(udid?.isEmpty == false)

        let video = session.video
        try await video.start()
        var frames = 0
        let subscription = video.frames.compactMap { $0 }.sink { _ in frames += 1 }
        let first = try #require(video.frames.value)
        print("video: \(CVPixelBufferGetWidth(first.pixelBuffer))x\(CVPixelBufferGetHeight(first.pixelBuffer)), screen \(session.client.serverHello.app.screen.size)")

        let simulator = try #require(udid)
        try setAppearance(simulator, "dark")
        try await Task.sleep(for: .milliseconds(800))
        try setAppearance(simulator, "light")
        try await Task.sleep(for: .milliseconds(800))
        subscription.cancel()
        print("video: \(frames) frames in 1.6 s")
        #expect(frames > 5)

        let image = try await video.snapshot(screen: try await session.screenInfo())
        video.stop()
        #expect(!video.isRunning)
        print("snapshot: \(image.width)x\(image.height)")
        if let path = ProcessInfo.processInfo.environment["SPLK_VIDEO_OUT"], let png = SPLKMCPPayload.png(of: image) {
            try png.write(to: URL(fileURLWithPath: path))
        }
    }
}
