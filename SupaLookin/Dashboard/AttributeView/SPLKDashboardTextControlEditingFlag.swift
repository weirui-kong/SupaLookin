//
//  SPLKDashboardTextControlEditingFlag.swift
//  SupaLookin
//
//  Created by likaimacbookhome on 2024/3/3.
//  Copyright © 2024 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation

final class SPLKDashboardTextControlEditingFlag {

    static let sharedInstance = SPLKDashboardTextControlEditingFlag()

    private init() {}

    var shouldIgnoreTextEditingChangeEvent = false
}
