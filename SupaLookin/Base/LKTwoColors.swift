//
//  LKTwoColors.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/9/30.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

/// colorInLightMode 是浅色模式下的颜色，colorInDarkMode 是深色模式下的颜色
final class LKTwoColors {

    var colorInLightMode: NSColor
    var colorInDarkMode: NSColor

    init(lightMode colorInLightMode: NSColor, darkMode colorInDarkMode: NSColor) {
        self.colorInLightMode = colorInLightMode
        self.colorInDarkMode = colorInDarkMode
    }

    /// 如果当前是 darkMode 则返回 colorInDarkMode，否则返回 colorInLightMode
    var color: NSColor {
        NSApp.effectiveAppearance.isDarkMode ? colorInDarkMode : colorInLightMode
    }
}
