//
//  SPLKConsoleDataSourceRowItem.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/1.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation

enum SPLKConsoleDataSourceRowItemType {
    case input
    case submit
    case `return`
}

final class SPLKConsoleDataSourceRowItem {

    var type: SPLKConsoleDataSourceRowItemType = .input

    var highlightText: String?

    var normalText: String?
}
