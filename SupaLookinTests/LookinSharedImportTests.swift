//
//  LookinSharedImportTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/10/25.
//

import Foundation
import Testing
import LookinShared

struct LookinSharedImportTests {

    @Test func clientVersionIsVisible() {
        #expect(LOOKIN_CLIENT_VERSION == 7)
    }

    @Test func displayItemRoundTripsThroughKeyedArchiver() throws {
        let item = LookinDisplayItem()
        item.frame = CGRect(x: 1, y: 2, width: 3, height: 4)
        item.isHidden = true

        let data = try NSKeyedArchiver.archivedData(withRootObject: item, requiringSecureCoding: true)
        let decoded = try #require(try NSKeyedUnarchiver.unarchivedObject(ofClass: LookinDisplayItem.self, from: data))

        #expect(decoded.frame == item.frame)
        #expect(decoded.isHidden)
    }
}
