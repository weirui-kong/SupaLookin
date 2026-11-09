//
//  SPLKMessageManager.swift
//  SupaLookin
//
//  Created by likai.123 on 2023/10/30.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation

let SPLKMessage_Jobs = "SPLKMessage_Jobs"
let SPLKMessage_NewServerVersion = "SPLKMessage_NewServerVersion"
let SPLKMessage_SwiftSubspec = "SPLKMessage_SwiftSubspec"

final class SPLKMessageManager {

    static let sharedInstance = SPLKMessageManager()

    private var messages = NSMutableSet()

    private init() {}

    func addMessage(_ message: String) {
        messages.add(message)
    }

    func removeMessage(_ message: String) {
        messages.remove(message)

        if message == SPLKMessage_Jobs {
            UserDefaults.standard.set(true, forKey: "LKMessageManager_HasReadJobs")
        }
    }

    /// Ordered by string length; messages of equal length keep NSSet's order, as the Objective-C sort did.
    func queryMessages() -> [String] {
        let strings = messages.allObjects.compactMap { $0 as? String }
        return (strings as NSArray).sortedArray { lhs, rhs in
            let lhsLength = (lhs as? NSString)?.length ?? 0
            let rhsLength = (rhs as? NSString)?.length ?? 0
            if lhsLength > rhsLength {
                return .orderedDescending
            } else if lhsLength == rhsLength {
                return .orderedSame
            }
            return .orderedAscending
        }.compactMap { $0 as? String }
    }

    #if DEBUG
    func reset() {
        UserDefaults.standard.removeObject(forKey: "LKMessageManager_HasReadJobs")
    }
    #endif
}
