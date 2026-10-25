//
//  LKTableViewHorizontalScrollWidthManager.swift
//  SupaLookin
//
//  Created by likaimacbookhome on 2023/12/17.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation

final class LKTableViewHorizontalScrollWidthManager {

    var maxRowWidth: CGFloat = 0

    var didReachNewMaxWidth: (() -> Void)?

    func rowDidLayout(withWidth width: CGFloat) {
        if width > maxRowWidth {
            maxRowWidth = width
            didReachNewMaxWidth?()
        }
    }
}
