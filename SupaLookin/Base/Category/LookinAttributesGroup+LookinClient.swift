//
//  LookinAttributesGroup+LookinClient.swift
//  SupaLookin
//
//  Created by LikaiMacStudioWork on 2023/10/31.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import LookinShared

extension LookinAttributesGroup {

    func queryDisplayTitle() -> String {
        if let userCustomTitle, !userCustomTitle.isEmpty {
            return userCustomTitle
        }
        return LookinDashboardBlueprint.groupTitle(withGroupID: identifier) ?? ""
    }
}
