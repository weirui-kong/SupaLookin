//
//  LookinDocument.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/26.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LookinDocument: NSDocument {

    // NSDocument may call read(from:ofType:) off the main actor
    nonisolated(unsafe) var hierarchyFile: LookinHierarchyFile?

    override func makeWindowControllers() {
        let wc = LKReadWindowController(file: hierarchyFile)
        addWindowController(wc)
    }

    override func data(ofType typeName: String) throws -> Data {
        guard let hierarchyFile else {
            assertionFailure()
            throw LookinError.inner
        }

        if typeName == "com.lookin.lookin" {
            return try NSKeyedArchiver.archivedData(withRootObject: hierarchyFile, requiringSecureCoding: true)
        }

        throw LookinError.inner
    }

    nonisolated override func read(from data: Data, ofType typeName: String) throws {
        // verifyHierarchyFile: reports a non-LookinHierarchyFile object as an inner error
        guard let hierarchyFile = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSObject.self], from: data) as? LookinHierarchyFile else {
            throw LookinError.inner
        }

        if let verifyError = LookinHierarchyFile.verifyHierarchyFile(hierarchyFile) {
            throw verifyError
        }
        self.hierarchyFile = hierarchyFile
    }
}
