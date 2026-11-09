//
//  SPLKDocument.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/26.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import SPLKServer

final class SPLKDocument: NSDocument {

    static let typeIdentifier = "icu.retrouvailles.supalookin.document"
    static let fileExtension = "supalookin"

    // NSDocument may call read(from:ofType:) off the main actor
    nonisolated(unsafe) var hierarchyFile: SPLKHierarchyFile?

    override func makeWindowControllers() {
        let wc = SPLKReadWindowController(file: hierarchyFile)
        addWindowController(wc)
    }

    override func data(ofType typeName: String) throws -> Data {
        guard let hierarchyFile else {
            assertionFailure()
            throw SPLKError.inner
        }

        if typeName == Self.typeIdentifier {
            return try NSKeyedArchiver.archivedData(withRootObject: hierarchyFile, requiringSecureCoding: true)
        }

        throw SPLKError.inner
    }

    nonisolated override func read(from data: Data, ofType typeName: String) throws {
        // verifyHierarchyFile: reports a non-SPLKHierarchyFile object as an inner error
        let (object, isLegacy) = try SPLKHierarchyFile.unarchivedObject(from: data)
        guard let hierarchyFile = object as? SPLKHierarchyFile else {
            throw SPLKError.inner
        }

        if let verifyError = hierarchyFile.verificationError(isLegacy: isLegacy) {
            throw verifyError
        }
        self.hierarchyFile = hierarchyFile
    }
}
