//
//  SPLKServerImportTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/10/25.
//

import Foundation
import Testing
import SPLKServer
@testable import SupaLookin

struct SPLKServerImportTests {

    @Test func clientVersionIsVisible() {
        #expect(SPLK_CLIENT_VERSION == 1)
    }

    @Test func portsStayClearOfStockLookinServer() {
        #expect(SPLKSimulatorIPv4PortNumberStart == 47264)
        #expect(SPLKSimulatorIPv4PortNumberEnd == 47269)
        #expect(SPLKUSBDeviceIPv4PortNumberStart == 47275)
        #expect(SPLKUSBDeviceIPv4PortNumberEnd == 47279)
    }

    @Test func displayItemRoundTripsThroughKeyedArchiver() throws {
        let item = SPLKDisplayItem()
        item.frame = CGRect(x: 1, y: 2, width: 3, height: 4)
        item.isHidden = true

        let data = try NSKeyedArchiver.archivedData(withRootObject: item, requiringSecureCoding: true)
        let decoded = try #require(try NSKeyedUnarchiver.unarchivedObject(ofClass: SPLKDisplayItem.self, from: data))

        #expect(decoded.frame == item.frame)
        #expect(decoded.isHidden)
    }

    private func legacyDocumentData(serverVersion: Int32) throws -> Data {
        let item = SPLKDisplayItem()
        item.frame = CGRect(x: 1, y: 2, width: 3, height: 4)
        let info = SPLKHierarchyInfo()
        info.displayItems = [item]
        let file = SPLKHierarchyFile()
        file.serverVersion = serverVersion
        file.hierarchyInfo = info

        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        for archivedClass: AnyClass in [SPLKHierarchyFile.self, SPLKHierarchyInfo.self, SPLKDisplayItem.self] {
            archiver.setClassName("Lookin" + NSStringFromClass(archivedClass).dropFirst("SPLK".count), for: archivedClass)
        }
        archiver.encode(file, forKey: NSKeyedArchiveRootObjectKey)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    @Test func stockLookinDocumentReads() throws {
        let document = SPLKDocument()
        try document.read(from: try legacyDocumentData(serverVersion: 7), ofType: "com.lookin.lookin")
        let file = try #require(document.hierarchyFile)
        #expect(file.serverVersion == 7)
        #expect(file.hierarchyInfo?.displayItems?.first?.frame == CGRect(x: 1, y: 2, width: 3, height: 4))
    }

    @Test func stockLookinDocumentOfOtherVersionIsRejected() throws {
        let document = SPLKDocument()
        #expect(throws: (any Error).self) {
            try document.read(from: try legacyDocumentData(serverVersion: 8), ofType: "com.lookin.lookin")
        }
    }
}
