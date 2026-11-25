//
//  SPLKMaskItemsTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/11/25.
//

import Cocoa
import Testing
import SPLKServer
@testable import SupaLookin

struct SPLKMaskItemsTests {

    private func item(_ oid: UInt, subitems: [SPLKDisplayItem] = []) -> SPLKDisplayItem {
        let item = SPLKDisplayItem()
        let object = SPLKObject()
        object.oid = oid
        item.layerObject = object
        item.subitems = subitems
        return item
    }

    // root > owner > (child, mask > maskChild)
    private func makeTree() -> (root: SPLKDisplayItem, owner: SPLKDisplayItem, mask: SPLKDisplayItem, maskChild: SPLKDisplayItem) {
        let maskChild = item(5)
        let mask = item(4, subitems: [maskChild])
        mask.isMask = true
        let owner = item(2, subitems: [item(3)])
        owner.mask = mask
        return (item(1, subitems: [owner]), owner, mask, maskChild)
    }

    @Test func theSwitchJoinsAndRemovesTheMask() {
        let tree = makeTree()
        SPLKDisplayItem.applyMaskVisibility(to: [tree.root], showsMasks: true)
        #expect(tree.owner.subitems?.count == 2)
        #expect(tree.owner.subitems?.last === tree.mask)
        #expect(tree.mask.`super` === tree.owner)
        #expect(tree.maskChild.maskOwner === tree.owner)

        SPLKDisplayItem.applyMaskVisibility(to: [tree.root], showsMasks: false)
        #expect(tree.owner.subitems?.count == 1)
        #expect(tree.mask.`super` == nil)
        #expect(tree.owner.mask === tree.mask)
    }

    @Test func fetchedChildrenSplitOutTheMask() {
        let owner = item(2)
        let mask = item(4)
        mask.isMask = true
        owner.replaceChildren(with: [item(3), mask], showsMasks: false)
        #expect(owner.subitems?.count == 1)
        #expect(owner.mask === mask)
    }

    @Test func documentsKeepTheMaskApart() throws {
        let tree = makeTree()
        SPLKDisplayItem.applyMaskVisibility(to: [tree.root], showsMasks: true)
        let data = try NSKeyedArchiver.archivedData(withRootObject: tree.root, requiringSecureCoding: false)
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        let decoded = try #require(unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? SPLKDisplayItem)
        let owner = try #require(decoded.subitems?.first)
        #expect(owner.subitems?.count == 1)
        #expect(owner.mask?.isMask == true)
        #expect(owner.mask?.subitems?.first?.layerObject?.oid == 5)
        #expect(owner.subitems?.first?.isMask == false)
    }

    @Test func hidingMasksSelectsTheOwner() {
        let tree = makeTree()
        let info = SPLKHierarchyInfo()
        info.displayItems = [tree.root]
        let file = SPLKHierarchyFile()
        file.hierarchyInfo = info
        let manager = SPLKPreferenceManager()
        manager.showMaskItems.setBOOLValue(true, ignoreSubscriber: nil)
        let dataSource = SPLKReadHierarchyDataSource(file: file, preferenceManager: manager)
        #expect(dataSource.flatItems.contains { $0 === tree.maskChild })

        dataSource.selectedItem = tree.maskChild
        manager.showMaskItems.setBOOLValue(false, ignoreSubscriber: nil)
        #expect(dataSource.selectedItem === tree.owner)
        #expect(!dataSource.flatItems.contains { $0 === tree.mask })
    }
}
