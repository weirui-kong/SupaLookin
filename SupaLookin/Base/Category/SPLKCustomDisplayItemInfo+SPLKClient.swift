//
//  SPLKCustomDisplayItemInfo+SPLKClient.swift
//  SupaLookin
//
//  Created by likai.123 on 2023/11/1.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import SPLKServer

extension SPLKCustomDisplayItemInfo {

    func hasValidFrame() -> Bool {
        guard let frameInWindow else {
            return false
        }
        return SPLKHelper.validateFrame(frameInWindow.rectValue)
    }
}
