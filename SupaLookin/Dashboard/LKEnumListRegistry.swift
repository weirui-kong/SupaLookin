//
//  LKEnumListRegistry.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/21.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation

final class LKEnumListRegistryKeyValueItem {

    let desc: String
    let value: Int
    let availableOSVersion: Int

    init(desc: String, value: Int, availableOSVersion: Int) {
        self.desc = desc
        self.value = value
        self.availableOSVersion = availableOSVersion
    }
}

private func makeItem(_ desc: String, _ value: Int, availableOSVersion: Int = 0) -> LKEnumListRegistryKeyValueItem {
    LKEnumListRegistryKeyValueItem(desc: desc, value: value, availableOSVersion: availableOSVersion)
}

final class LKEnumListRegistry {

    static let sharedInstance = LKEnumListRegistry()

    private let data: [String: [LKEnumListRegistryKeyValueItem]]

    private init() {
        var mData: [String: [LKEnumListRegistryKeyValueItem]] = [:]

        mData["UIControlContentVerticalAlignment"] = [
            makeItem("UIControlContentVerticalAlignmentCenter", 0),
            makeItem("UIControlContentVerticalAlignmentTop", 1),
            makeItem("UIControlContentVerticalAlignmentBottom", 2),
            makeItem("UIControlContentVerticalAlignmentFill", 3),
        ]

        mData["UIControlContentHorizontalAlignment"] = [
            makeItem("UIControlContentHorizontalAlignmentCenter", 0),
            makeItem("UIControlContentHorizontalAlignmentLeft", 1),
            makeItem("UIControlContentHorizontalAlignmentRight", 2),
            makeItem("UIControlContentHorizontalAlignmentFill", 3),
            makeItem("UIControlContentHorizontalAlignmentLeading", 4, availableOSVersion: 11),
            makeItem("UIControlContentHorizontalAlignmentTrailing", 5, availableOSVersion: 11),
        ]

        mData["UIViewContentMode"] = [
            makeItem("UIViewContentModeScaleToFill", 0),
            makeItem("UIViewContentModeScaleAspectFit", 1),
            makeItem("UIViewContentModeScaleAspectFill", 2),
            makeItem("UIViewContentModeRedraw", 3),
            makeItem("UIViewContentModeCenter", 4),
            makeItem("UIViewContentModeTop", 5),
            makeItem("UIViewContentModeBottom", 6),
            makeItem("UIViewContentModeLeft", 7),
            makeItem("UIViewContentModeRight", 8),
            makeItem("UIViewContentModeTopLeft", 9),
            makeItem("UIViewContentModeTopRight", 10),
            makeItem("UIViewContentModeBottomLeft", 11),
            makeItem("UIViewContentModeBottomRight", 12),
        ]

        mData["UIViewTintAdjustmentMode"] = [
            makeItem("UIViewTintAdjustmentModeAutomatic", 0),
            makeItem("UIViewTintAdjustmentModeNormal", 1),
            makeItem("UIViewTintAdjustmentModeDimmed", 2),
        ]

        mData["NSTextAlignment"] = [
            makeItem("NSTextAlignmentLeft", 0),
            makeItem("NSTextAlignmentCenter", 1),
            makeItem("NSTextAlignmentRight", 2),
            makeItem("NSTextAlignmentJustified", 3),
            makeItem("NSTextAlignmentNatural", 4),
        ]

        mData["NSLineBreakMode"] = [
            makeItem("NSLineBreakByWordWrapping", 0),
            makeItem("NSLineBreakByCharWrapping", 1),
            makeItem("NSLineBreakByClipping", 2),
            makeItem("NSLineBreakByTruncatingHead", 3),
            makeItem("NSLineBreakByTruncatingTail", 4),
            makeItem("NSLineBreakByTruncatingMiddle", 5),
        ]

        mData["UIScrollViewContentInsetAdjustmentBehavior"] = [
            makeItem("UIScrollViewContentInsetAdjustmentAutomatic", 0),
            makeItem("UIScrollViewContentInsetAdjustmentScrollableAxes", 1),
            makeItem("UIScrollViewContentInsetAdjustmentNever", 2),
            makeItem("UIScrollViewContentInsetAdjustmentAlways", 3),
        ]

        mData["UITableViewStyle"] = [
            makeItem("UITableViewStylePlain", 0),
            makeItem("UITableViewStyleGrouped", 1),
        ]

        mData["UITextFieldViewMode"] = [
            makeItem("UITextFieldViewModeNever", 0),
            makeItem("UITextFieldViewModeWhileEditing", 1),
            makeItem("UITextFieldViewModeUnlessEditing", 2),
            makeItem("UITextFieldViewModeAlways", 3),
        ]

        mData["UIAccessibilityNavigationStyle"] = [
            makeItem("UIAccessibilityNavigationStyleAutomatic", 0),
            makeItem("UIAccessibilityNavigationStyleSeparate", 1),
            makeItem("UIAccessibilityNavigationStyleCombined", 2),
        ]

        mData["QMUIButtonImagePosition"] = [
            makeItem("QMUIButtonImagePositionTop", 0),
            makeItem("QMUIButtonImagePositionLeft", 1),
            makeItem("QMUIButtonImagePositionBottom", 2),
            makeItem("QMUIButtonImagePositionRight", 3),
        ]

        mData["UITableViewCellSeparatorStyle"] = [
            makeItem("UITableViewCellSeparatorStyleNone", 0),
            makeItem("UITableViewCellSeparatorStyleSingleLine", 1),
            makeItem("UITableViewCellSeparatorStyleSingleLineEtched", 2),
        ]

        mData["UIBlurEffectStyle"] = [
            makeItem("UIBlurEffectStyleExtraLight", 0),
            makeItem("UIBlurEffectStyleLight", 1),
            makeItem("UIBlurEffectStyleDark", 2),
            // UIBlurEffectStyleExtraDark (3): 该值被官方标注了 API_UNAVAILABLE(ios)，因此这里跳过
            makeItem("UIBlurEffectStyleRegular", 4, availableOSVersion: 10),
            makeItem("UIBlurEffectStyleProminent", 5, availableOSVersion: 10),
            makeItem("UIBlurEffectStyleSystemUltraThinMaterial", 6, availableOSVersion: 13),
            makeItem("UIBlurEffectStyleSystemThinMaterial", 7, availableOSVersion: 13),
            makeItem("UIBlurEffectStyleSystemMaterial", 8, availableOSVersion: 13),
            makeItem("UIBlurEffectStyleSystemThickMaterial", 9, availableOSVersion: 13),
            makeItem("UIBlurEffectStyleSystemChromeMaterial", 10, availableOSVersion: 13),
            makeItem("UIBlurEffectStyleSystemUltraThinMaterialLight", 11, availableOSVersion: 13),
            makeItem("UIBlurEffectStyleSystemThinMaterialLight", 12, availableOSVersion: 13),
            makeItem("UIBlurEffectStyleSystemMaterialLight", 13, availableOSVersion: 13),
            makeItem("UIBlurEffectStyleSystemThickMaterialLight", 14, availableOSVersion: 13),
            makeItem("UIBlurEffectStyleSystemChromeMaterialLight", 15, availableOSVersion: 13),
            makeItem("UIBlurEffectStyleSystemUltraThinMaterialDark", 16, availableOSVersion: 13),
            makeItem("UIBlurEffectStyleSystemThinMaterialDark", 17, availableOSVersion: 13),
            makeItem("UIBlurEffectStyleSystemMaterialDark", 18, availableOSVersion: 13),
            makeItem("UIBlurEffectStyleSystemThickMaterialDark", 19, availableOSVersion: 13),
            makeItem("UIBlurEffectStyleSystemChromeMaterialDark", 20, availableOSVersion: 13),
        ]

        mData["UILayoutConstraintAxis"] = [
            makeItem("UILayoutConstraintAxisHorizontal", 0),
            makeItem("UILayoutConstraintAxisVertical", 1),
        ]

        mData["UIStackViewDistribution"] = [
            makeItem("UIStackViewDistributionFill", 0),
            makeItem("UIStackViewDistributionFillEqually", 1),
            makeItem("UIStackViewDistributionFillProportionally", 2),
            makeItem("UIStackViewDistributionEqualSpacing", 3),
            makeItem("UIStackViewDistributionEqualCentering", 4),
        ]

        mData["UIStackViewAlignment"] = [
            makeItem("UIStackViewAlignmentFill", 0),
            makeItem("UIStackViewAlignmentLeading (Top)", 1),
            makeItem("UIStackViewAlignmentFirstBaseline", 2),
            makeItem("UIStackViewAlignmentCenter", 3),
            makeItem("UIStackViewAlignmentTrailing (Bottom)", 4),
            makeItem("UIStackViewAlignmentLastBaseline", 5),
        ]

        data = mData
    }

    func items(forEnumName enumName: String) -> [LKEnumListRegistryKeyValueItem]? {
        data[enumName]
    }

    func desc(forEnumName enumName: String, value: Int) -> String? {
        guard let items = items(forEnumName: enumName) else {
            assertionFailure()
            return nil
        }
        return items.first { $0.value == value }?.desc
    }
}
