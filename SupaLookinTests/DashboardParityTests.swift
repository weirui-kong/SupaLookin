//
//  DashboardParityTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/10/25.
//

import Cocoa
import Testing
import LookinShared
@testable import SupaLookin

struct DashboardParityTests {

    @Test func enumRegistryMatchesLookin() throws {
        let registry = LKEnumListRegistry.sharedInstance
        #expect(registry.desc(forEnumName: "NSTextAlignment", value: 1) == "NSTextAlignmentCenter")
        #expect(registry.desc(forEnumName: "UIViewContentMode", value: 12) == "UIViewContentModeBottomRight")
        #expect(registry.desc(forEnumName: "UIBlurEffectStyle", value: 3) == nil)

        let leading = try #require(registry.items(forEnumName: "UIControlContentHorizontalAlignment")?.first { $0.value == 4 })
        #expect(leading.desc == "UIControlContentHorizontalAlignmentLeading")
        #expect(leading.availableOSVersion == 11)
        #expect(registry.items(forEnumName: "UIBlurEffectStyle")?.count == 20)
    }

    @Test func jsonItemsFlattenWithIndentation() throws {
        let json = """
        [{"title": "a", "desc": "1", "details": [{"title": "b", "details": [{"title": "c"}]}]}, {"title": "d"}, "ignored"]
        """
        let roots = try #require(LKJSONAttributeItem.rootItems(fromJSON: json))
        #expect(roots.count == 2)

        let flat = roots.flatMap { $0.flatItems() }
        #expect(flat.map { $0.titleText } == ["a", "b", "c", "d"])
        #expect(flat.map { $0.indentation } == [0, 1, 2, 0])
        #expect(flat[0].desc == "1")

        roots[0].expanded = false
        #expect(roots.flatMap { $0.flatItems() }.map { $0.titleText } == ["a", "d"])

        #expect(LKJSONAttributeItem.rootItems(fromJSON: "{}") == nil)
    }

    @Test func exportedDocumentReadsBack() throws {
        let item = LookinDisplayItem()
        item.frame = CGRect(x: 1, y: 2, width: 3, height: 4)
        let info = LookinHierarchyInfo()
        info.displayItems = [item]
        info.serverVersion = LOOKIN_SERVER_VERSION
        let appInfo = LookinAppInfo()
        appInfo.appName = "Demo"
        appInfo.osDescription = "17.2"
        info.appInfo = appInfo

        let (data, fileName) = LKExportManager.sharedInstance.data(from: info, imageCompression: 0.5)
        #expect(fileName?.hasPrefix("Demo_ios17_") == true)
        #expect(fileName?.hasSuffix(".lookin") == true)

        let document = LookinDocument()
        try document.read(from: try #require(data), ofType: "com.lookin.lookin")
        let file = try #require(document.hierarchyFile)
        #expect(file.serverVersion == LOOKIN_SERVER_VERSION)
        #expect(file.hierarchyInfo?.displayItems?.first?.frame == item.frame)
    }
}
