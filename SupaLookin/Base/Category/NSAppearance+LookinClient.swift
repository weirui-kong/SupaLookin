//
//  NSAppearance+LookinClient.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/3/4.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

extension NSAppearance {

    var isDarkMode: Bool {
        [NSAppearance.Name.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark].contains(name)
    }
}
