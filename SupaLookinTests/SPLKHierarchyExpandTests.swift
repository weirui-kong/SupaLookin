//
//  SPLKHierarchyExpandTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/11/19.
//

import Cocoa
import Testing
import SPLKServer
@testable import SupaLookin

struct SPLKHierarchyExpandTests {

    // A chain `levels` deep below the root, each level with a leaf beside the next.
    private func makeChain(levels: Int) -> [SPLKDisplayItem] {
        var chain: [SPLKDisplayItem] = []
        var child: SPLKDisplayItem?
        for _ in 0...levels {
            let item = SPLKDisplayItem()
            item.subitems = [child, SPLKDisplayItem()].compactMap { $0 }
            chain.insert(item, at: 0)
            child = item
        }
        return chain
    }

    @Test func expandsTheGivenNumberOfLevels() {
        let chain = makeChain(levels: 4)
        let deepest = chain[4]
        deepest.isExpanded = true

        SPLKHierarchyDataSource.expand(chain[0], levels: 3)
        let opened = chain[0...2].allSatisfy { $0.isExpanded }
        #expect(opened)
        #expect(!chain[3].isExpanded)
        #expect(deepest.isExpanded)
    }

    @Test func leavesItemsThatPreferToBeCollapsed() {
        let chain = makeChain(levels: 4)
        chain[1].preferToBeCollapsed = true

        SPLKHierarchyDataSource.expand(chain[0], levels: 3)
        #expect(chain[0].isExpanded)
        #expect(!chain[1].isExpanded)
        #expect(chain[2].isExpanded)

        let clicked = makeChain(levels: 4)
        clicked.forEach { $0.preferToBeCollapsed = true }
        SPLKHierarchyDataSource.expand(clicked[0], levels: 3)
        let clickedOpened = clicked[0...2].allSatisfy { $0.isExpanded }
        #expect(clickedOpened)
    }
}

struct SPLKHierarchyDepthPreferenceTests {

    @Test func onlyAChosenDepthIsRemembered() throws {
        let suiteName = "SupaLookinTests.depth.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let preferences = SPLKPreferenceManager(userDefaults: userDefaults)
        preferences.expansionIndex = 3
        let dataSource = SPLKReadHierarchyDataSource(file: nil, preferenceManager: preferences)

        dataSource.adjustExpansion(byIndex: 0, referenceDict: nil, remembersIndex: false)
        #expect(preferences.expansionIndex == 3)

        dataSource.adjustExpansion(byIndex: 1, referenceDict: nil)
        #expect(preferences.expansionIndex == 1)
    }
}
