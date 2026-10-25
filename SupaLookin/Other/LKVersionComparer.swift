//
//  LKVersionComparer.swift
//  SupaLookin
//
//  Created by likai.123 on 2023/10/30.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import LookinShared

enum LKVersionComparer {

    /// latest 指网上最高的 LookinServer 版本号，user 指用户真实的版本号。如果用户版本号低于最高版本号，则该方法返回 false，此时应该提示用户升级。
    static func compare(withNewest latest: String, user: String) -> Bool {
        compare(withExpectedVersion: latest, realVersion: user)
    }

    /// 如果 realVersion 等于或高于 expectedVersion，则该方法返回 true（换句话说：用户的实际版本号满足我们的需要）
    static func compare(withExpectedVersion expectedVersion: String, realVersion: String) -> Bool {
        let expectedNumber = (expectedVersion as NSString).lookin_numbericOSVersion()
        let realNumber = (realVersion as NSString).lookin_numbericOSVersion()
        if expectedNumber == 0 || realNumber == 0 {
            assertionFailure()
            return false
        }
        return realNumber >= expectedNumber
    }
}
