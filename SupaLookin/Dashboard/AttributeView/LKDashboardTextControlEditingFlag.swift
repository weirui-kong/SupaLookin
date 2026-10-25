//
//  LKDashboardTextControlEditingFlag.swift
//  SupaLookin
//
//  Created by likaimacbookhome on 2024/3/3.
//  Copyright © 2024 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation

final class LKDashboardTextControlEditingFlag {

    static let sharedInstance = LKDashboardTextControlEditingFlag()

    private init() {}

    var shouldIgnoreTextEditingChangeEvent = false
}
