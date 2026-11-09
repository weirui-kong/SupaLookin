//
//  SPLKHierarchyFile+SPLKClient.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/9.
//

import Foundation
import SPLKServer

extension SPLKHierarchyFile {

    // .lookin documents written by stock Lookin archive these classes under their "Lookin" names
    private nonisolated static var legacyArchivedClasses: [AnyClass] {
        [
            SPLKAppInfo.self, SPLKAttribute.self, SPLKAttributeModification.self, SPLKAttributesGroup.self,
            SPLKAttributesSection.self, SPLKAutoLayoutConstraint.self, SPLKCustomAttrModification.self, SPLKCustomDisplayItemInfo.self,
            SPLKDisplayItem.self, SPLKDisplayItemDetail.self, SPLKEventHandler.self, SPLKHierarchyFile.self,
            SPLKHierarchyInfo.self, SPLKIvarTrace.self, SPLKObject.self, SPLKStaticAsyncUpdateTask.self,
            SPLKStaticAsyncUpdateTasksPackage.self, SPLKStringTwoTuple.self, SPLKTwoTuple.self,
        ]
    }

    // The only protocol version stock Lookin's last client accepted
    private nonisolated static let legacyServerVersion: Int32 = 7

    nonisolated static func unarchivedObject(from data: Data) throws -> (object: Any?, isLegacy: Bool) {
        do {
            return (try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSObject.self], from: data), false)
        } catch {
            guard let legacyObject = try? legacyUnarchivedObject(from: data) else {
                throw error
            }
            return (legacyObject, true)
        }
    }

    private nonisolated static func legacyUnarchivedObject(from data: Data) throws -> Any? {
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        for archivedClass in legacyArchivedClasses {
            let name = NSStringFromClass(archivedClass)
            unarchiver.setClass(archivedClass, forClassName: "Lookin" + name.dropFirst("SPLK".count))
        }
        defer { unarchiver.finishDecoding() }
        return try unarchiver.decodeTopLevelObject(of: [NSObject.self], forKey: NSKeyedArchiveRootObjectKey)
    }

    nonisolated func verificationError(isLegacy: Bool) -> Error? {
        guard isLegacy else {
            return Self.verifyHierarchyFile(self)
        }

        let legacyVersion = Self.legacyServerVersion
        if serverVersion < legacyVersion {
            let fileVersion = serverVersion != 0 ? serverVersion : 6
            let detail = String(format: NSLocalizedString("The document was created by a Lookin app with too old version. Current Lookin app version is %@, but the document version is %@.", comment: ""), NSNumber(value: legacyVersion), NSNumber(value: fileVersion))
            return NSError(domain: SPLKErrorDomain, code: SPLKErrCode_ServerVersionTooLow, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Failed to open the document.", comment: ""),
                NSLocalizedRecoverySuggestionErrorKey: detail,
            ])
        }
        if serverVersion > legacyVersion {
            let detail = String(format: NSLocalizedString("Current Lookin app is too old to open this document. Current Lookin app version is %@, but the document version is %@.", comment: ""), NSNumber(value: legacyVersion), NSNumber(value: serverVersion))
            return NSError(domain: SPLKErrorDomain, code: SPLKErrCode_ServerVersionTooHigh, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Failed to open the document.", comment: ""),
                NSLocalizedRecoverySuggestionErrorKey: detail,
            ])
        }
        return nil
    }
}
