#ifdef SHOULD_COMPILE_SPLK_SHARED

//
//  SPLKDashboardBlueprint.m
//  Lookin
//
//  Created by Li Kai on 2019/6/5.
//  https://lookin.work
//



#import "SPLKDashboardBlueprint.h"

@implementation SPLKDashboardBlueprint

+ (NSArray<SPLKAttrGroupIdentifier> *)groupIDs {
    static NSArray<SPLKAttrGroupIdentifier> *array;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        array = @[
            SPLKAttrGroup_Class,
            SPLKAttrGroup_Relation,
            SPLKAttrGroup_Layout,
            SPLKAttrGroup_AutoLayout,
            SPLKAttrGroup_ViewLayer,
            SPLKAttrGroup_UIStackView,
            SPLKAttrGroup_UIVisualEffectView,
            SPLKAttrGroup_UIImageView,
            SPLKAttrGroup_UILabel,
            SPLKAttrGroup_UIControl,
            SPLKAttrGroup_UIButton,
            SPLKAttrGroup_UIScrollView,
            SPLKAttrGroup_UITableView,
            SPLKAttrGroup_UITextView,
            SPLKAttrGroup_UITextField
        ];
    });
    return array;
}

+ (NSArray<SPLKAttrSectionIdentifier> *)sectionIDsForGroupID:(SPLKAttrGroupIdentifier)groupID {
    static NSDictionary<SPLKAttrGroupIdentifier, NSArray<SPLKAttrSectionIdentifier> *> *dict;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        dict = @{
            SPLKAttrGroup_Class: @[SPLKAttrSec_Class_Class],
            
            SPLKAttrGroup_Relation: @[SPLKAttrSec_Relation_Relation],
            
            SPLKAttrGroup_Layout: @[SPLKAttrSec_Layout_Frame,
                                      SPLKAttrSec_Layout_Bounds,
                                      SPLKAttrSec_Layout_SafeArea,
                                      SPLKAttrSec_Layout_Position,
                                      SPLKAttrSec_Layout_AnchorPoint],
            
            SPLKAttrGroup_AutoLayout: @[SPLKAttrSec_AutoLayout_Constraints,
                                          SPLKAttrSec_AutoLayout_IntrinsicSize,
                                          SPLKAttrSec_AutoLayout_Hugging,
                                          SPLKAttrSec_AutoLayout_Resistance],
            
            SPLKAttrGroup_ViewLayer: @[
                SPLKAttrSec_ViewLayer_Visibility,
                SPLKAttrSec_ViewLayer_InterationAndMasks,
                SPLKAttrSec_ViewLayer_BgColor,
                SPLKAttrSec_ViewLayer_Border,
                SPLKAttrSec_ViewLayer_Corner,
                SPLKAttrSec_ViewLayer_Shadow,
                SPLKAttrSec_ViewLayer_ContentMode,
                SPLKAttrSec_ViewLayer_TintColor,
                SPLKAttrSec_ViewLayer_Tag
            ],
            
            SPLKAttrGroup_UIStackView: @[
                SPLKAttrSec_UIStackView_Axis,
                SPLKAttrSec_UIStackView_Distribution,
                SPLKAttrSec_UIStackView_Alignment,
                SPLKAttrSec_UIStackView_Spacing
            ],
            
            SPLKAttrGroup_UIVisualEffectView: @[
                SPLKAttrSec_UIVisualEffectView_Style,
                SPLKAttrSec_UIVisualEffectView_QMUIForegroundColor
            ],
            
            SPLKAttrGroup_UIImageView: @[SPLKAttrSec_UIImageView_Name,
                                           SPLKAttrSec_UIImageView_Open],
            
            SPLKAttrGroup_UILabel: @[
                SPLKAttrSec_UILabel_Text,
                SPLKAttrSec_UILabel_Font,
                SPLKAttrSec_UILabel_NumberOfLines,
                SPLKAttrSec_UILabel_TextColor,
                SPLKAttrSec_UILabel_BreakMode,
                SPLKAttrSec_UILabel_Alignment,
                SPLKAttrSec_UILabel_CanAdjustFont],
            
            SPLKAttrGroup_UIControl: @[SPLKAttrSec_UIControl_EnabledSelected,
                                         SPLKAttrSec_UIControl_QMUIOutsideEdge,
                                         SPLKAttrSec_UIControl_VerAlignment,
                                         SPLKAttrSec_UIControl_HorAlignment],
            
            SPLKAttrGroup_UIButton: @[SPLKAttrSec_UIButton_ContentInsets,
                                        SPLKAttrSec_UIButton_TitleInsets,
                                        SPLKAttrSec_UIButton_ImageInsets],
            
            SPLKAttrGroup_UIScrollView: @[SPLKAttrSec_UIScrollView_ContentInset,
                                            SPLKAttrSec_UIScrollView_AdjustedInset,
                                            SPLKAttrSec_UIScrollView_QMUIInitialInset,
                                            SPLKAttrSec_UIScrollView_IndicatorInset,
                                            SPLKAttrSec_UIScrollView_Offset,
                                            SPLKAttrSec_UIScrollView_ContentSize,
                                            SPLKAttrSec_UIScrollView_Behavior,
                                            SPLKAttrSec_UIScrollView_ShowsIndicator,
                                            SPLKAttrSec_UIScrollView_Bounce,
                                            SPLKAttrSec_UIScrollView_ScrollPaging,
                                            SPLKAttrSec_UIScrollView_ContentTouches,
                                            SPLKAttrSec_UIScrollView_Zoom],
            
            SPLKAttrGroup_UITableView: @[SPLKAttrSec_UITableView_Style,
                                           SPLKAttrSec_UITableView_SectionsNumber,
                                           SPLKAttrSec_UITableView_RowsNumber,
                                           SPLKAttrSec_UITableView_SeparatorStyle,
                                           SPLKAttrSec_UITableView_SeparatorColor,
                                           SPLKAttrSec_UITableView_SeparatorInset],
            
            SPLKAttrGroup_UITextView: @[SPLKAttrSec_UITextView_Basic,
                                          SPLKAttrSec_UITextView_Text,
                                          SPLKAttrSec_UITextView_Font,
                                          SPLKAttrSec_UITextView_TextColor,
                                          SPLKAttrSec_UITextView_Alignment,
                                          SPLKAttrSec_UITextView_ContainerInset],
            
            SPLKAttrGroup_UITextField: @[SPLKAttrSec_UITextField_Text,
                                           SPLKAttrSec_UITextField_Placeholder,
                                           SPLKAttrSec_UITextField_Font,
                                           SPLKAttrSec_UITextField_TextColor,
                                           SPLKAttrSec_UITextField_Alignment,
                                           SPLKAttrSec_UITextField_Clears,
                                           SPLKAttrSec_UITextField_CanAdjustFont,
                                           SPLKAttrSec_UITextField_ClearButtonMode],
            
        };
    });
    return dict[groupID];
}

+ (NSArray<SPLKAttrIdentifier> *)attrIDsForSectionID:(SPLKAttrSectionIdentifier)sectionID {
    static NSDictionary<SPLKAttrSectionIdentifier, NSArray<SPLKAttrIdentifier> *> *dict;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        dict = @{
            SPLKAttrSec_Class_Class: @[SPLKAttr_Class_Class_Class],
            
            SPLKAttrSec_Relation_Relation: @[SPLKAttr_Relation_Relation_Relation],
            
            SPLKAttrSec_Layout_Frame: @[SPLKAttr_Layout_Frame_Frame],
            SPLKAttrSec_Layout_Bounds: @[SPLKAttr_Layout_Bounds_Bounds],
            SPLKAttrSec_Layout_SafeArea: @[SPLKAttr_Layout_SafeArea_SafeArea],
            SPLKAttrSec_Layout_Position: @[SPLKAttr_Layout_Position_Position],
            SPLKAttrSec_Layout_AnchorPoint: @[SPLKAttr_Layout_AnchorPoint_AnchorPoint],
            
            SPLKAttrSec_AutoLayout_Hugging: @[SPLKAttr_AutoLayout_Hugging_Hor,
                                                SPLKAttr_AutoLayout_Hugging_Ver],
            SPLKAttrSec_AutoLayout_Resistance: @[SPLKAttr_AutoLayout_Resistance_Hor,
                                                   SPLKAttr_AutoLayout_Resistance_Ver],
            SPLKAttrSec_AutoLayout_Constraints: @[SPLKAttr_AutoLayout_Constraints_Constraints],
            SPLKAttrSec_AutoLayout_IntrinsicSize: @[SPLKAttr_AutoLayout_IntrinsicSize_Size],
            
            SPLKAttrSec_ViewLayer_Visibility: @[SPLKAttr_ViewLayer_Visibility_Hidden,
                                                  SPLKAttr_ViewLayer_Visibility_Opacity],
            
            SPLKAttrSec_ViewLayer_InterationAndMasks: @[SPLKAttr_ViewLayer_InterationAndMasks_Interaction,
                                                          SPLKAttr_ViewLayer_InterationAndMasks_MasksToBounds],
            
            SPLKAttrSec_ViewLayer_Corner: @[SPLKAttr_ViewLayer_Corner_Radius],
            
            SPLKAttrSec_ViewLayer_BgColor: @[SPLKAttr_ViewLayer_BgColor_BgColor],
            
            SPLKAttrSec_ViewLayer_Border: @[SPLKAttr_ViewLayer_Border_Color,
                                              SPLKAttr_ViewLayer_Border_Width],
            
            SPLKAttrSec_ViewLayer_Shadow: @[SPLKAttr_ViewLayer_Shadow_Color,
                                              SPLKAttr_ViewLayer_Shadow_Opacity,
                                              SPLKAttr_ViewLayer_Shadow_Radius,
                                              SPLKAttr_ViewLayer_Shadow_OffsetW,
                                              SPLKAttr_ViewLayer_Shadow_OffsetH],
            
            SPLKAttrSec_ViewLayer_ContentMode: @[SPLKAttr_ViewLayer_ContentMode_Mode],
            
            SPLKAttrSec_ViewLayer_TintColor: @[SPLKAttr_ViewLayer_TintColor_Color,
                                                 SPLKAttr_ViewLayer_TintColor_Mode],
            
            SPLKAttrSec_ViewLayer_Tag: @[SPLKAttr_ViewLayer_Tag_Tag],
            
            SPLKAttrSec_UIStackView_Axis: @[SPLKAttr_UIStackView_Axis_Axis],
            
            SPLKAttrSec_UIStackView_Distribution: @[SPLKAttr_UIStackView_Distribution_Distribution],
            
            SPLKAttrSec_UIStackView_Alignment: @[SPLKAttr_UIStackView_Alignment_Alignment],
            
            SPLKAttrSec_UIStackView_Spacing: @[SPLKAttr_UIStackView_Spacing_Spacing],
            
            SPLKAttrSec_UIVisualEffectView_Style: @[SPLKAttr_UIVisualEffectView_Style_Style],
            
            SPLKAttrSec_UIVisualEffectView_QMUIForegroundColor: @[SPLKAttr_UIVisualEffectView_QMUIForegroundColor_Color],
            
            SPLKAttrSec_UIImageView_Name: @[SPLKAttr_UIImageView_Name_Name],
            
            SPLKAttrSec_UIImageView_Open: @[SPLKAttr_UIImageView_Open_Open],
            
            SPLKAttrSec_UILabel_Font: @[SPLKAttr_UILabel_Font_Name,
                                          SPLKAttr_UILabel_Font_Size],
            
            SPLKAttrSec_UILabel_NumberOfLines: @[SPLKAttr_UILabel_NumberOfLines_NumberOfLines],
            
            SPLKAttrSec_UILabel_Text: @[SPLKAttr_UILabel_Text_Text],
            
            SPLKAttrSec_UILabel_TextColor: @[SPLKAttr_UILabel_TextColor_Color],
            
            SPLKAttrSec_UILabel_BreakMode: @[SPLKAttr_UILabel_BreakMode_Mode],
            
            SPLKAttrSec_UILabel_Alignment: @[SPLKAttr_UILabel_Alignment_Alignment],
            
            SPLKAttrSec_UILabel_CanAdjustFont: @[SPLKAttr_UILabel_CanAdjustFont_CanAdjustFont],
            
            SPLKAttrSec_UIControl_EnabledSelected: @[SPLKAttr_UIControl_EnabledSelected_Enabled,
                                                       SPLKAttr_UIControl_EnabledSelected_Selected],
            
            SPLKAttrSec_UIControl_QMUIOutsideEdge: @[SPLKAttr_UIControl_QMUIOutsideEdge_Edge],
            
            SPLKAttrSec_UIControl_VerAlignment: @[SPLKAttr_UIControl_VerAlignment_Alignment],
            
            SPLKAttrSec_UIControl_HorAlignment: @[SPLKAttr_UIControl_HorAlignment_Alignment],
            
            SPLKAttrSec_UIButton_ContentInsets: @[SPLKAttr_UIButton_ContentInsets_Insets],
            
            SPLKAttrSec_UIButton_TitleInsets: @[SPLKAttr_UIButton_TitleInsets_Insets],
            
            SPLKAttrSec_UIButton_ImageInsets: @[SPLKAttr_UIButton_ImageInsets_Insets],
            
            SPLKAttrSec_UIScrollView_ContentInset: @[SPLKAttr_UIScrollView_ContentInset_Inset],
            
            SPLKAttrSec_UIScrollView_AdjustedInset: @[SPLKAttr_UIScrollView_AdjustedInset_Inset],
            
            SPLKAttrSec_UIScrollView_QMUIInitialInset: @[SPLKAttr_UIScrollView_QMUIInitialInset_Inset],
            
            SPLKAttrSec_UIScrollView_IndicatorInset: @[SPLKAttr_UIScrollView_IndicatorInset_Inset],
            
            SPLKAttrSec_UIScrollView_Offset: @[SPLKAttr_UIScrollView_Offset_Offset],
            
            SPLKAttrSec_UIScrollView_ContentSize: @[SPLKAttr_UIScrollView_ContentSize_Size],
            
            SPLKAttrSec_UIScrollView_Behavior: @[SPLKAttr_UIScrollView_Behavior_Behavior],
            
            SPLKAttrSec_UIScrollView_ShowsIndicator: @[SPLKAttr_UIScrollView_ShowsIndicator_Hor,
                                                         SPLKAttr_UIScrollView_ShowsIndicator_Ver],
            
            SPLKAttrSec_UIScrollView_Bounce: @[SPLKAttr_UIScrollView_Bounce_Hor,
                                                 SPLKAttr_UIScrollView_Bounce_Ver],
            
            SPLKAttrSec_UIScrollView_ScrollPaging: @[SPLKAttr_UIScrollView_ScrollPaging_ScrollEnabled,
                                                       SPLKAttr_UIScrollView_ScrollPaging_PagingEnabled],
            
            SPLKAttrSec_UIScrollView_ContentTouches: @[SPLKAttr_UIScrollView_ContentTouches_Delay,
                                                         SPLKAttr_UIScrollView_ContentTouches_CanCancel],
            
            SPLKAttrSec_UIScrollView_Zoom: @[SPLKAttr_UIScrollView_Zoom_Bounce,
                                               SPLKAttr_UIScrollView_Zoom_Scale,
                                               SPLKAttr_UIScrollView_Zoom_MinScale,
                                               SPLKAttr_UIScrollView_Zoom_MaxScale],
            
            SPLKAttrSec_UITableView_Style: @[SPLKAttr_UITableView_Style_Style],
            
            SPLKAttrSec_UITableView_SectionsNumber: @[SPLKAttr_UITableView_SectionsNumber_Number],
            
            SPLKAttrSec_UITableView_RowsNumber: @[SPLKAttr_UITableView_RowsNumber_Number],
            
            SPLKAttrSec_UITableView_SeparatorInset: @[SPLKAttr_UITableView_SeparatorInset_Inset],
            
            SPLKAttrSec_UITableView_SeparatorColor: @[SPLKAttr_UITableView_SeparatorColor_Color],
            
            SPLKAttrSec_UITableView_SeparatorStyle: @[SPLKAttr_UITableView_SeparatorStyle_Style],
            
            SPLKAttrSec_UITextView_Basic: @[SPLKAttr_UITextView_Basic_Editable,
                                              SPLKAttr_UITextView_Basic_Selectable],
            
            SPLKAttrSec_UITextView_Text: @[SPLKAttr_UITextView_Text_Text],
            
            SPLKAttrSec_UITextView_Font: @[SPLKAttr_UITextView_Font_Name,
                                             SPLKAttr_UITextView_Font_Size],
            
            SPLKAttrSec_UITextView_TextColor: @[SPLKAttr_UITextView_TextColor_Color],
            
            SPLKAttrSec_UITextView_Alignment: @[SPLKAttr_UITextView_Alignment_Alignment],
            
            SPLKAttrSec_UITextView_ContainerInset: @[SPLKAttr_UITextView_ContainerInset_Inset],
            
            SPLKAttrSec_UITextField_Text: @[SPLKAttr_UITextField_Text_Text],
            
            SPLKAttrSec_UITextField_Placeholder: @[SPLKAttr_UITextField_Placeholder_Placeholder],
            
            SPLKAttrSec_UITextField_Font: @[SPLKAttr_UITextField_Font_Name,
                                              SPLKAttr_UITextField_Font_Size],
            
            SPLKAttrSec_UITextField_TextColor: @[SPLKAttr_UITextField_TextColor_Color],
            
            SPLKAttrSec_UITextField_Alignment: @[SPLKAttr_UITextField_Alignment_Alignment],
            
            SPLKAttrSec_UITextField_Clears: @[SPLKAttr_UITextField_Clears_ClearsOnBeginEditing,
                                                SPLKAttr_UITextField_Clears_ClearsOnInsertion],
            
            SPLKAttrSec_UITextField_CanAdjustFont: @[SPLKAttr_UITextField_CanAdjustFont_CanAdjustFont,
                                                       SPLKAttr_UITextField_CanAdjustFont_MinSize],
            
            SPLKAttrSec_UITextField_ClearButtonMode: @[SPLKAttr_UITextField_ClearButtonMode_Mode]
        };
    });
    return dict[sectionID];
}

+ (void)getHostGroupID:(inout SPLKAttrGroupIdentifier *)groupID_inout sectionID:(inout SPLKAttrSectionIdentifier *)sectionID_inout fromAttrID:(SPLKAttrIdentifier)targetAttrID {
    __block SPLKAttrGroupIdentifier targetGroupID = nil;
    __block SPLKAttrSectionIdentifier targetSecID = nil;
    [[self groupIDs] enumerateObjectsUsingBlock:^(SPLKAttrGroupIdentifier _Nonnull groupID, NSUInteger idx, BOOL * _Nonnull stop0) {
        [[self sectionIDsForGroupID:groupID] enumerateObjectsUsingBlock:^(SPLKAttrSectionIdentifier _Nonnull secID, NSUInteger idx, BOOL * _Nonnull stop1) {
            [[self attrIDsForSectionID:secID] enumerateObjectsUsingBlock:^(SPLKAttrIdentifier _Nonnull attrID, NSUInteger idx, BOOL * _Nonnull stop2) {
                if ([attrID isEqualToString:targetAttrID]) {
                    targetGroupID = groupID;
                    targetSecID = secID;
                    *stop0 = YES;
                    *stop1 = YES;
                    *stop2 = YES;
                }
            }];
        }];
    }];
    
    if (groupID_inout && targetGroupID) {
        *groupID_inout = targetGroupID;
    }
    if (sectionID_inout && targetSecID) {
        *sectionID_inout = targetSecID;
    }
}

+ (NSString *)groupTitleWithGroupID:(SPLKAttrGroupIdentifier)groupID {
    static dispatch_once_t onceToken;
    static NSDictionary *rawInfo = nil;
    dispatch_once(&onceToken,^{
        rawInfo = @{
            SPLKAttrGroup_Class: @"Class",
            SPLKAttrGroup_Relation: @"Relation",
            SPLKAttrGroup_Layout: @"Layout",
            SPLKAttrGroup_AutoLayout: @"AutoLayout",
            SPLKAttrGroup_ViewLayer: @"CALayer / UIView",
            SPLKAttrGroup_UIImageView: @"UIImageView",
            SPLKAttrGroup_UILabel: @"UILabel",
            SPLKAttrGroup_UIControl: @"UIControl",
            SPLKAttrGroup_UIButton: @"UIButton",
            SPLKAttrGroup_UIScrollView: @"UIScrollView",
            SPLKAttrGroup_UITableView: @"UITableView",
            SPLKAttrGroup_UITextView: @"UITextView",
            SPLKAttrGroup_UITextField: @"UITextField",
            SPLKAttrGroup_UIVisualEffectView: @"UIVisualEffectView",
            SPLKAttrGroup_UIStackView: @"UIStackView"
        };
    });
    NSString *title = rawInfo[groupID];
    NSAssert(title.length, @"");
    return title;
}

+ (NSString *)sectionTitleWithSectionID:(SPLKAttrSectionIdentifier)secID {
    static dispatch_once_t onceToken;
    static NSDictionary *rawInfo = nil;
    dispatch_once(&onceToken,^{
        rawInfo = @{
            SPLKAttrSec_Layout_Frame: @"Frame",
            SPLKAttrSec_Layout_Bounds: @"Bounds",
            SPLKAttrSec_Layout_SafeArea: @"SafeArea",
            SPLKAttrSec_Layout_Position: @"Position",
            SPLKAttrSec_Layout_AnchorPoint: @"AnchorPoint",
            SPLKAttrSec_AutoLayout_Hugging: @"HuggingPriority",
            SPLKAttrSec_AutoLayout_Resistance: @"ResistancePriority",
            SPLKAttrSec_AutoLayout_IntrinsicSize: @"IntrinsicSize",
            SPLKAttrSec_ViewLayer_Corner: @"CornerRadius",
            SPLKAttrSec_ViewLayer_BgColor: @"BackgroundColor",
            SPLKAttrSec_ViewLayer_Border: @"Border",
            SPLKAttrSec_ViewLayer_Shadow: @"Shadow",
            SPLKAttrSec_ViewLayer_ContentMode: @"ContentMode",
            SPLKAttrSec_ViewLayer_TintColor: @"TintColor",
            SPLKAttrSec_ViewLayer_Tag: @"Tag",
            SPLKAttrSec_UIStackView_Axis: @"Axis",
            SPLKAttrSec_UIStackView_Distribution: @"Distribution",
            SPLKAttrSec_UIStackView_Alignment: @"Alignment",
            SPLKAttrSec_UIVisualEffectView_Style: @"Style",
            SPLKAttrSec_UIVisualEffectView_QMUIForegroundColor: @"ForegroundColor",
            SPLKAttrSec_UIImageView_Name: @"ImageName",
            SPLKAttrSec_UILabel_TextColor: @"TextColor",
            SPLKAttrSec_UITextView_TextColor: @"TextColor",
            SPLKAttrSec_UITextField_TextColor: @"TextColor",
            SPLKAttrSec_UILabel_BreakMode: @"LineBreakMode",
            SPLKAttrSec_UILabel_NumberOfLines: @"NumberOfLines",
            SPLKAttrSec_UILabel_Text: @"Text",
            SPLKAttrSec_UITextView_Text: @"Text",
            SPLKAttrSec_UITextField_Text: @"Text",
            SPLKAttrSec_UITextField_Placeholder: @"Placeholder",
            SPLKAttrSec_UILabel_Alignment: @"TextAlignment",
            SPLKAttrSec_UITextView_Alignment: @"TextAlignment",
            SPLKAttrSec_UITextField_Alignment: @"TextAlignment",
            SPLKAttrSec_UIControl_HorAlignment: @"HorizontalAlignment",
            SPLKAttrSec_UIControl_VerAlignment: @"VerticalAlignment",
            SPLKAttrSec_UIControl_QMUIOutsideEdge: @"QMUI_outsideEdge",
            SPLKAttrSec_UIButton_ContentInsets: @"ContentInsets",
            SPLKAttrSec_UIButton_TitleInsets: @"TitleInsets",
            SPLKAttrSec_UIButton_ImageInsets: @"ImageInsets",
            SPLKAttrSec_UIScrollView_QMUIInitialInset: @"QMUI_initialContentInset",
            SPLKAttrSec_UIScrollView_ContentInset: @"ContentInset",
            SPLKAttrSec_UIScrollView_AdjustedInset: @"AdjustedContentInset",
            SPLKAttrSec_UIScrollView_IndicatorInset: @"ScrollIndicatorInsets",
            SPLKAttrSec_UIScrollView_Offset: @"ContentOffset",
            SPLKAttrSec_UIScrollView_ContentSize: @"ContentSize",
            SPLKAttrSec_UIScrollView_Behavior: @"InsetAdjustmentBehavior",
            SPLKAttrSec_UIScrollView_ShowsIndicator: @"ShowsScrollIndicator",
            SPLKAttrSec_UIScrollView_Bounce: @"AlwaysBounce",
            SPLKAttrSec_UIScrollView_Zoom: @"Zoom",
            SPLKAttrSec_UITableView_Style: @"Style",
            SPLKAttrSec_UITableView_SectionsNumber: @"NumberOfSections",
            SPLKAttrSec_UITableView_RowsNumber: @"NumberOfRows",
            SPLKAttrSec_UITableView_SeparatorColor: @"SeparatorColor",
            SPLKAttrSec_UITableView_SeparatorInset: @"SeparatorInset",
            SPLKAttrSec_UITableView_SeparatorStyle: @"SeparatorStyle",
            SPLKAttrSec_UILabel_Font: @"Font",
            SPLKAttrSec_UITextField_Font: @"Font",
            SPLKAttrSec_UITextView_Font: @"Font",
            SPLKAttrSec_UITextView_ContainerInset: @"ContainerInset",
            SPLKAttrSec_UITextField_ClearButtonMode: @"ClearButtonMode",
        };
    });
    return rawInfo[secID];
}

/**
 className: 必填项，标识该属性是哪一个类拥有的
 
 fullTitle: 完整的名字，将作为搜索的 keywords，也会展示在搜索结果中，如果为 nil 则不会被搜索到
 
 briefTitle：简略的名字，仅 checkbox 和那种自带标题的 input 才需要这个属性，如果需要该属性但该属性又为空，则会读取 fullTitle
 
 setterString：用户试图修改属性值时会用到，若该字段为空字符串（即 @“”）则该属性不可修改，若该字段为 nil 则会在 fullTitle 的基础上自动生成（自动改首字母大小写、加前缀后缀，比如 alpha 会被转换为 setAlpha:）
 
 getterString：必填项，业务中读取属性值时会用到。如果该字段为 nil ，则会在 fullTitle 的基础上自动生成（自动把 fullTitle 的第一个字母改成小写，比如 Alpha 会被转换为 alpha）。如果该字段为空字符串（比如 image_open_open）则属性值会被固定为 nil，attrType 会被指为 SPLKAttrTypeCustomObj
 
 typeIfObj：当某个 SPLKAttribute 确定是 NSObject 类型时，该方法返回它具体是什么对象，比如 UIColor、NSString
 
 enumList：如果某个 attribute 是 enum，则这里标识了相应的 enum 的名称（如 "NSTextAlignment"），业务可通过这个名称进而查询可用的枚举值列表
 
 patch：如果为 YES，则用户修改了该 Attribute 的值后，Lookin 会重新拉取和更新相关图层的位置、截图等信息，如果为 nil 则默认是 NO
 
 hideIfNil：如果为 YES，则当获取的 value 为 nil 时，Lookin 不会传输该 attr。如果为 NO，则即使 value 为 nil 也会传输（比如 label 的 text 属性，即使它是 nil 我们也要显示，所以它的 hideIfNil 应该为 NO）。如果该字段为 nil 则默认是 NO
 
 osVersion: 该属性需要的最低的 iOS 版本，比如 safeAreaInsets 从 iOS 11.0 开始出现，则该属性应该为 @11，如果为 nil 则表示不限制 iOS 版本
 
 */
+ (NSDictionary<NSString *, id> *)_infoForAttrID:(SPLKAttrIdentifier)attrID {
    static NSDictionary<SPLKAttrIdentifier, NSDictionary<NSString *, id> *> *dict;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        dict = @{
            SPLKAttr_Class_Class_Class: @{
                @"className": @"CALayer",
                @"getterString": @"splk_relatedClassChainList",
                @"setterString": @"",
                @"typeIfObj": @(SPLKAttrTypeCustomObj)
            },
            
            SPLKAttr_Relation_Relation_Relation: @{
                @"className": @"CALayer",
                @"getterString": @"splk_selfRelation",
                @"setterString": @"",
                @"typeIfObj": @(SPLKAttrTypeCustomObj),
                @"hideIfNil": @(YES)
            },
            
            SPLKAttr_Layout_Frame_Frame: @{
                @"className": @"CALayer",
                @"fullTitle": @"Frame",
                @"patch": @(YES)
            },
            SPLKAttr_Layout_Bounds_Bounds: @{
                @"className": @"CALayer",
                @"fullTitle": @"Bounds",
                @"patch": @(YES)
            },
            SPLKAttr_Layout_SafeArea_SafeArea: @{
                @"className": @"UIView",
                @"fullTitle": @"SafeAreaInsets",
                @"setterString": @"",
                @"osVersion": @(11)
            },
            SPLKAttr_Layout_Position_Position: @{
                @"className": @"CALayer",
                @"fullTitle": @"Position",
                @"patch": @(YES)
            },
            SPLKAttr_Layout_AnchorPoint_AnchorPoint: @{
                @"className": @"CALayer",
                @"fullTitle": @"AnchorPoint",
                @"patch": @(YES)
            },
            
            SPLKAttr_AutoLayout_Hugging_Hor: @{
                @"className": @"UIView",
                @"fullTitle": @"ContentHuggingPriority(Horizontal)",
                @"getterString": @"splk_horizontalContentHuggingPriority",
                @"setterString": @"setSplk_horizontalContentHuggingPriority:",
                @"briefTitle": @"H",
                @"patch": @(YES)
            },
            SPLKAttr_AutoLayout_Hugging_Ver: @{
                @"className": @"UIView",
                @"fullTitle": @"ContentHuggingPriority(Vertical)",
                @"getterString": @"splk_verticalContentHuggingPriority",
                @"setterString": @"setSplk_verticalContentHuggingPriority:",
                @"briefTitle": @"V",
                @"patch": @(YES)
            },
            SPLKAttr_AutoLayout_Resistance_Hor: @{
                @"className": @"UIView",
                @"fullTitle": @"ContentCompressionResistancePriority(Horizontal)",
                @"getterString": @"splk_horizontalContentCompressionResistancePriority",
                @"setterString": @"setSplk_horizontalContentCompressionResistancePriority:",
                @"briefTitle": @"H",
                @"patch": @(YES)
            },
            SPLKAttr_AutoLayout_Resistance_Ver: @{
                @"className": @"UIView",
                @"fullTitle": @"ContentCompressionResistancePriority(Vertical)",
                @"getterString": @"splk_verticalContentCompressionResistancePriority",
                @"setterString": @"setSplk_verticalContentCompressionResistancePriority:",
                @"briefTitle": @"V",
                @"patch": @(YES)
            },
            SPLKAttr_AutoLayout_Constraints_Constraints: @{
                @"className": @"UIView",
                @"getterString": @"splk_constraints",
                @"setterString": @"",
                @"typeIfObj": @(SPLKAttrTypeCustomObj),
                @"hideIfNil": @(YES)
            },
            SPLKAttr_AutoLayout_IntrinsicSize_Size: @{
                @"className": @"UIView",
                @"fullTitle": @"IntrinsicContentSize",
                @"setterString": @""
            },
            
            SPLKAttr_ViewLayer_Visibility_Hidden: @{
                @"className": @"CALayer",
                @"fullTitle": @"Hidden",
                @"getterString": @"isHidden",
                @"patch": @(YES)
            },
            SPLKAttr_ViewLayer_Visibility_Opacity: @{
                @"className": @"CALayer",
                @"fullTitle": @"Opacity / Alpha",
                @"setterString": @"setOpacity:",
                @"getterString": @"opacity",
                @"patch": @(YES)
            },
            SPLKAttr_ViewLayer_InterationAndMasks_Interaction: @{
                @"className": @"UIView",
                @"fullTitle": @"UserInteractionEnabled",
                @"getterString": @"isUserInteractionEnabled",
                @"patch": @(NO)
            },
            SPLKAttr_ViewLayer_InterationAndMasks_MasksToBounds: @{
                @"className": @"CALayer",
                @"fullTitle": @"MasksToBounds / ClipsToBounds",
                @"briefTitle": @"MasksToBounds",
                @"setterString": @"setMasksToBounds:",
                @"getterString": @"masksToBounds",
                @"patch": @(YES)
            },
            SPLKAttr_ViewLayer_Corner_Radius: @{
                @"className": @"CALayer",
                @"fullTitle": @"CornerRadius",
                @"briefTitle": @"",
                @"patch": @(YES)
            },
            SPLKAttr_ViewLayer_BgColor_BgColor: @{
                @"className": @"CALayer",
                @"fullTitle": @"BackgroundColor",
                @"setterString": @"setSplk_backgroundColor:",
                @"getterString": @"splk_backgroundColor",
                @"typeIfObj": @(SPLKAttrTypeUIColor),
                @"patch": @(YES)
            },
            SPLKAttr_ViewLayer_Border_Color: @{
                @"className": @"CALayer",
                @"fullTitle": @"BorderColor",
                @"setterString": @"setSplk_borderColor:",
                @"getterString": @"splk_borderColor",
                @"typeIfObj": @(SPLKAttrTypeUIColor),
                @"patch": @(YES)
            },
            SPLKAttr_ViewLayer_Border_Width: @{
                @"className": @"CALayer",
                @"fullTitle": @"BorderWidth",
                @"patch": @(YES)
            },
            SPLKAttr_ViewLayer_Shadow_Color: @{
                @"className": @"CALayer",
                @"fullTitle": @"ShadowColor",
                @"setterString": @"setSplk_shadowColor:",
                @"getterString": @"splk_shadowColor",
                @"typeIfObj": @(SPLKAttrTypeUIColor),
                @"patch": @(YES)
            },
            SPLKAttr_ViewLayer_Shadow_Opacity: @{
                @"className": @"CALayer",
                @"fullTitle": @"ShadowOpacity",
                @"briefTitle": @"Opacity",
                @"patch": @(YES)
            },
            SPLKAttr_ViewLayer_Shadow_Radius: @{
                @"className": @"CALayer",
                @"fullTitle": @"ShadowRadius",
                @"briefTitle": @"Radius",
                @"patch": @(YES)
            },
            SPLKAttr_ViewLayer_Shadow_OffsetW: @{
                @"className": @"CALayer",
                @"fullTitle": @"ShadowOffsetWidth",
                @"briefTitle": @"OffsetW",
                @"setterString": @"setSplk_shadowOffsetWidth:",
                @"getterString": @"splk_shadowOffsetWidth",
                @"patch": @(YES)
            },
            SPLKAttr_ViewLayer_Shadow_OffsetH: @{
                @"className": @"CALayer",
                @"fullTitle": @"ShadowOffsetHeight",
                @"briefTitle": @"OffsetH",
                @"setterString": @"setSplk_shadowOffsetHeight:",
                @"getterString": @"splk_shadowOffsetHeight",
                @"patch": @(YES)
            },
            SPLKAttr_ViewLayer_ContentMode_Mode: @{
                @"className": @"UIView",
                @"fullTitle": @"ContentMode",
                @"enumList": @"UIViewContentMode",
                @"patch": @(YES)
            },
            SPLKAttr_ViewLayer_TintColor_Color: @{
                @"className": @"UIView",
                @"fullTitle": @"TintColor",
                @"typeIfObj": @(SPLKAttrTypeUIColor),
                @"patch": @(YES)
            },
            SPLKAttr_ViewLayer_TintColor_Mode: @{
                @"className": @"UIView",
                @"fullTitle": @"TintAdjustmentMode",
                @"enumList": @"UIViewTintAdjustmentMode",
                @"patch": @(YES)
            },
            SPLKAttr_ViewLayer_Tag_Tag: @{
                @"className": @"UIView",
                @"fullTitle": @"Tag",
                @"briefTitle": @"",
                @"patch": @(NO)
            },
            
            SPLKAttr_UIStackView_Axis_Axis: @{
                @"className": @"UIStackView",
                @"fullTitle": @"Axis",
                @"enumList": @"UILayoutConstraintAxis",
                @"patch": @(YES)
            },
            
            SPLKAttr_UIStackView_Distribution_Distribution: @{
                @"className": @"UIStackView",
                @"fullTitle": @"Distribution",
                @"enumList": @"UIStackViewDistribution",
                @"patch": @(YES)
            },
            
            SPLKAttr_UIStackView_Alignment_Alignment: @{
                @"className": @"UIStackView",
                @"fullTitle": @"Alignment",
                @"enumList": @"UIStackViewAlignment",
                @"patch": @(YES)
            },
            
            SPLKAttr_UIStackView_Spacing_Spacing: @{
                @"className": @"UIStackView",
                @"fullTitle": @"Spacing",
                @"patch": @(YES)
            },
            
            SPLKAttr_UIVisualEffectView_Style_Style: @{
                @"className": @"UIVisualEffectView",
                @"setterString": @"setSplk_blurEffectStyleNumber:",
                @"getterString": @"splk_blurEffectStyleNumber",
                @"enumList": @"UIBlurEffectStyle",
                @"typeIfObj": @(SPLKAttrTypeCustomObj),
                @"patch": @(YES),
                @"hideIfNil": @(YES)
            },
            
            SPLKAttr_UIVisualEffectView_QMUIForegroundColor_Color: @{
                @"className": @"QMUIVisualEffectView",
                @"fullTitle": @"ForegroundColor",
                @"typeIfObj": @(SPLKAttrTypeUIColor),
                @"patch": @(YES),
            },
            
            SPLKAttr_UIImageView_Name_Name: @{
                @"className": @"UIImageView",
                @"fullTitle": @"ImageName",
                @"setterString": @"",
                @"getterString": @"splk_imageSourceName",
                @"typeIfObj": @(SPLKAttrTypeNSString),
                @"hideIfNil": @(YES)
            },
            SPLKAttr_UIImageView_Open_Open: @{
                @"className": @"UIImageView",
                @"setterString": @"",
                @"getterString": @"splk_imageViewOidIfHasImage",
                @"typeIfObj": @(SPLKAttrTypeCustomObj),
                @"hideIfNil": @(YES)
            },
            
            SPLKAttr_UILabel_Text_Text: @{
                @"className": @"UILabel",
                @"fullTitle": @"Text",
                @"typeIfObj": @(SPLKAttrTypeNSString),
                @"patch": @(YES)
            },
            SPLKAttr_UILabel_NumberOfLines_NumberOfLines: @{
                @"className": @"UILabel",
                @"fullTitle": @"NumberOfLines",
                @"briefTitle": @"",
                @"patch": @(YES)
            },
            SPLKAttr_UILabel_Font_Size: @{
                @"className": @"UILabel",
                @"fullTitle": @"FontSize",
                @"briefTitle": @"FontSize",
                @"setterString": @"setSplk_fontSize:",
                @"getterString": @"splk_fontSize",
                @"patch": @(YES)
            },
            SPLKAttr_UILabel_Font_Name: @{
                @"className": @"UILabel",
                @"fullTitle": @"FontName",
                @"setterString": @"",
                @"getterString": @"splk_fontName",
                @"typeIfObj": @(SPLKAttrTypeNSString),
                @"patch": @(NO)
            },
            SPLKAttr_UILabel_TextColor_Color: @{
                @"className": @"UILabel",
                @"fullTitle": @"TextColor",
                @"typeIfObj": @(SPLKAttrTypeUIColor),
                @"patch": @(YES)
            },
            SPLKAttr_UILabel_Alignment_Alignment: @{
                @"className": @"UILabel",
                @"fullTitle": @"TextAlignment",
                @"enumList": @"NSTextAlignment",
                @"patch": @(YES)
            },
            SPLKAttr_UILabel_BreakMode_Mode: @{
                @"className": @"UILabel",
                @"fullTitle": @"LineBreakMode",
                @"enumList": @"NSLineBreakMode",
                @"patch": @(YES)
            },
            SPLKAttr_UILabel_CanAdjustFont_CanAdjustFont: @{
                @"className": @"UILabel",
                @"fullTitle": @"AdjustsFontSizeToFitWidth",
                @"patch": @(YES)
            },
            
            SPLKAttr_UIControl_EnabledSelected_Enabled: @{
                @"className": @"UIControl",
                @"fullTitle": @"Enabled",
                @"getterString": @"isEnabled",
                @"patch": @(NO)
            },
            SPLKAttr_UIControl_EnabledSelected_Selected: @{
                @"className": @"UIControl",
                @"fullTitle": @"Selected",
                @"getterString": @"isSelected",
                @"patch": @(YES)
            },
            SPLKAttr_UIControl_VerAlignment_Alignment: @{
                @"className": @"UIControl",
                @"fullTitle": @"ContentVerticalAlignment",
                @"enumList": @"UIControlContentVerticalAlignment",
                @"patch": @(YES)
            },
            SPLKAttr_UIControl_HorAlignment_Alignment: @{
                @"className": @"UIControl",
                @"fullTitle": @"ContentHorizontalAlignment",
                @"enumList": @"UIControlContentHorizontalAlignment",
                @"patch": @(YES)
            },
            SPLKAttr_UIControl_QMUIOutsideEdge_Edge: @{
                @"className": @"UIControl",
                @"fullTitle": @"qmui_outsideEdge"
            },
            
            SPLKAttr_UIButton_ContentInsets_Insets: @{
                @"className": @"UIButton",
                @"fullTitle": @"ContentEdgeInsets",
                @"patch": @(YES)
            },
            SPLKAttr_UIButton_TitleInsets_Insets: @{
                @"className": @"UIButton",
                @"fullTitle": @"TitleEdgeInsets",
                @"patch": @(YES)
            },
            SPLKAttr_UIButton_ImageInsets_Insets: @{
                @"className": @"UIButton",
                @"fullTitle": @"ImageEdgeInsets",
                @"patch": @(YES)
            },
            
            SPLKAttr_UIScrollView_Offset_Offset: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"ContentOffset",
                @"patch": @(YES)
            },
            SPLKAttr_UIScrollView_ContentSize_Size: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"ContentSize",
                @"patch": @(YES)
            },
            SPLKAttr_UIScrollView_ContentInset_Inset: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"ContentInset",
                @"patch": @(YES)
            },
            SPLKAttr_UIScrollView_QMUIInitialInset_Inset: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"qmui_initialContentInset",
                @"patch": @(YES)
            },
            SPLKAttr_UIScrollView_AdjustedInset_Inset: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"AdjustedContentInset",
                @"setterString": @"",
                @"osVersion": @(11)
            },
            SPLKAttr_UIScrollView_Behavior_Behavior: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"ContentInsetAdjustmentBehavior",
                @"enumList": @"UIScrollViewContentInsetAdjustmentBehavior",
                @"patch": @(YES),
                @"osVersion": @(11)
            },
            SPLKAttr_UIScrollView_IndicatorInset_Inset: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"ScrollIndicatorInsets",
                @"patch": @(NO)
            },
            SPLKAttr_UIScrollView_ScrollPaging_ScrollEnabled: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"ScrollEnabled",
                @"getterString": @"isScrollEnabled",
                @"patch": @(NO)
            },
            SPLKAttr_UIScrollView_ScrollPaging_PagingEnabled: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"PagingEnabled",
                @"getterString": @"isPagingEnabled",
                @"patch": @(NO)
            },
            SPLKAttr_UIScrollView_Bounce_Ver: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"AlwaysBounceVertical",
                @"briefTitle": @"Vertical",
                @"patch": @(NO)
            },
            SPLKAttr_UIScrollView_Bounce_Hor: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"AlwaysBounceHorizontal",
                @"briefTitle": @"Horizontal",
                @"patch": @(NO)
            },
            SPLKAttr_UIScrollView_ShowsIndicator_Hor: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"ShowsHorizontalScrollIndicator",
                @"briefTitle": @"Horizontal",
                @"patch": @(NO)
            },
            SPLKAttr_UIScrollView_ShowsIndicator_Ver: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"ShowsVerticalScrollIndicator",
                @"briefTitle": @"Vertical",
                @"patch": @(NO)
            },
            SPLKAttr_UIScrollView_ContentTouches_Delay: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"DelaysContentTouches",
                @"patch": @(NO)
            },
            SPLKAttr_UIScrollView_ContentTouches_CanCancel: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"CanCancelContentTouches",
                @"patch": @(NO)
            },
            SPLKAttr_UIScrollView_Zoom_MinScale: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"MinimumZoomScale",
                @"briefTitle": @"MinScale",
                @"patch": @(NO)
            },
            SPLKAttr_UIScrollView_Zoom_MaxScale: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"MaximumZoomScale",
                @"briefTitle": @"MaxScale",
                @"patch": @(NO)
            },
            SPLKAttr_UIScrollView_Zoom_Scale: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"ZoomScale",
                @"briefTitle": @"Scale",
                @"patch": @(YES)
            },
            SPLKAttr_UIScrollView_Zoom_Bounce: @{
                @"className": @"UIScrollView",
                @"fullTitle": @"BouncesZoom",
                @"patch": @(NO)
            },
            
            SPLKAttr_UITableView_Style_Style: @{
                @"className": @"UITableView",
                @"fullTitle": @"Style",
                @"setterString": @"",
                @"enumList": @"UITableViewStyle",
                @"patch": @(YES)
            },
            SPLKAttr_UITableView_SectionsNumber_Number: @{
                @"className": @"UITableView",
                @"fullTitle": @"NumberOfSections",
                @"setterString": @"",
                @"patch": @(YES)
            },
            SPLKAttr_UITableView_RowsNumber_Number: @{
                @"className": @"UITableView",
                @"setterString": @"",
                @"getterString": @"splk_numberOfRows",
                @"typeIfObj": @(SPLKAttrTypeCustomObj)
            },
            SPLKAttr_UITableView_SeparatorInset_Inset: @{
                @"className": @"UITableView",
                @"fullTitle": @"SeparatorInset",
                @"patch": @(NO)
            },
            SPLKAttr_UITableView_SeparatorColor_Color: @{
                @"className": @"UITableView",
                @"fullTitle": @"SeparatorColor",
                @"typeIfObj": @(SPLKAttrTypeUIColor),
                @"patch": @(YES)
            },
            SPLKAttr_UITableView_SeparatorStyle_Style: @{
                @"className": @"UITableView",
                @"fullTitle": @"SeparatorStyle",
                @"enumList": @"UITableViewCellSeparatorStyle",
                @"patch": @(YES)
            },
            
            SPLKAttr_UITextView_Text_Text: @{
                @"className": @"UITextView",
                @"fullTitle": @"Text",
                @"typeIfObj": @(SPLKAttrTypeNSString),
                @"patch": @(YES)
            },
            SPLKAttr_UITextView_Font_Name: @{
                @"className": @"UITextView",
                @"fullTitle": @"FontName",
                @"setterString": @"",
                @"getterString": @"splk_fontName",
                @"typeIfObj": @(SPLKAttrTypeNSString),
                @"patch": @(NO)
            },
            SPLKAttr_UITextView_Font_Size: @{
                @"className": @"UITextView",
                @"fullTitle": @"FontSize",
                @"setterString": @"setSplk_fontSize:",
                @"getterString": @"splk_fontSize",
                @"patch": @(YES)
            },
            SPLKAttr_UITextView_Basic_Editable: @{
                @"className": @"UITextView",
                @"fullTitle": @"Editable",
                @"getterString": @"isEditable",
                @"patch": @(NO)
            },
            SPLKAttr_UITextView_Basic_Selectable: @{
                @"className": @"UITextView",
                @"fullTitle": @"Selectable",
                @"getterString": @"isSelectable",
                @"patch": @(NO)
            },
            SPLKAttr_UITextView_TextColor_Color: @{
                @"className": @"UITextView",
                @"fullTitle": @"TextColor",
                @"typeIfObj": @(SPLKAttrTypeUIColor),
                @"patch": @(YES)
            },
            SPLKAttr_UITextView_Alignment_Alignment: @{
                @"className": @"UITextView",
                @"fullTitle": @"TextAlignment",
                @"enumList": @"NSTextAlignment",
                @"patch": @(YES)
            },
            SPLKAttr_UITextView_ContainerInset_Inset: @{
                @"className": @"UITextView",
                @"fullTitle": @"TextContainerInset",
                @"patch": @(YES)
            },
            
            SPLKAttr_UITextField_Font_Name: @{
                @"className": @"UITextField",
                @"fullTitle": @"FontName",
                @"setterString": @"",
                @"getterString": @"splk_fontName",
                @"typeIfObj": @(SPLKAttrTypeNSString),
                @"patch": @(NO)
            },
            SPLKAttr_UITextField_Font_Size: @{
                @"className": @"UITextField",
                @"fullTitle": @"FontSize",
                @"setterString": @"setSplk_fontSize:",
                @"getterString": @"splk_fontSize",
                @"patch": @(YES)
            },
            SPLKAttr_UITextField_TextColor_Color: @{
                @"className": @"UITextField",
                @"fullTitle": @"TextColor",
                @"typeIfObj": @(SPLKAttrTypeUIColor),
                @"patch": @(YES)
            },
            SPLKAttr_UITextField_Alignment_Alignment: @{
                @"className": @"UITextField",
                @"fullTitle": @"TextAlignment",
                @"enumList": @"NSTextAlignment",
                @"patch": @(YES)
            },
            SPLKAttr_UITextField_Text_Text: @{
                @"className": @"UITextField",
                @"fullTitle": @"Text",
                @"typeIfObj": @(SPLKAttrTypeNSString),
                @"patch": @(YES)
            },
            SPLKAttr_UITextField_Placeholder_Placeholder: @{
                @"className": @"UITextField",
                @"fullTitle": @"Placeholder",
                @"typeIfObj": @(SPLKAttrTypeNSString),
                @"patch": @(YES)
            },
            SPLKAttr_UITextField_Clears_ClearsOnBeginEditing: @{
                @"className": @"UITextField",
                @"fullTitle": @"ClearsOnBeginEditing",
                @"patch": @(NO)
            },
            SPLKAttr_UITextField_Clears_ClearsOnInsertion: @{
                @"className": @"UITextField",
                @"fullTitle": @"ClearsOnInsertion",
                @"patch": @(NO)
            },
            SPLKAttr_UITextField_CanAdjustFont_CanAdjustFont: @{
                @"className": @"UITextField",
                @"fullTitle": @"AdjustsFontSizeToFitWidth",
                @"patch": @(YES)
            },
            SPLKAttr_UITextField_CanAdjustFont_MinSize: @{
                @"className": @"UITextField",
                @"fullTitle": @"MinimumFontSize",
                @"patch": @(YES)
            },
            SPLKAttr_UITextField_ClearButtonMode_Mode: @{
                @"className": @"UITextField",
                @"fullTitle": @"ClearButtonMode",
                @"enumList": @"UITextFieldViewMode",
                @"patch": @(NO)
            },
        };
    });
    
    NSDictionary<NSString *, id> *targetInfo = dict[attrID];
    return targetInfo;
}

+ (SPLKAttrType)objectAttrTypeWithAttrID:(SPLKAttrIdentifier)attrID {
    NSDictionary<NSString *, id> *attrInfo = [self _infoForAttrID:attrID];
    NSNumber *typeIfObj = attrInfo[@"typeIfObj"];
    return [typeIfObj integerValue];
}

+ (NSString *)classNameWithAttrID:(SPLKAttrIdentifier)attrID {
    NSDictionary<NSString *, id> *attrInfo = [self _infoForAttrID:attrID];
    NSString *className = attrInfo[@"className"];
    
    NSAssert(className.length > 0, @"");
    
    return className;
}

+ (BOOL)isUIViewPropertyWithAttrID:(SPLKAttrIdentifier)attrID {
    NSString *className = [self classNameWithAttrID:attrID];
    
    if ([className isEqualToString:@"CALayer"]) {
        return NO;
    }
    return YES;
}

+ (NSString *)enumListNameWithAttrID:(SPLKAttrIdentifier)attrID {
    NSDictionary<NSString *, id> *attrInfo = [self _infoForAttrID:attrID];
    NSString *name = attrInfo[@"enumList"];
    return name;
}

+ (BOOL)needPatchAfterModificationWithAttrID:(SPLKAttrIdentifier)attrID {
    NSDictionary<NSString *, id> *attrInfo = [self _infoForAttrID:attrID];
    NSNumber *needPatch = attrInfo[@"patch"];
    return [needPatch boolValue];
}

+ (NSString *)fullTitleWithAttrID:(SPLKAttrIdentifier)attrID {
    NSDictionary<NSString *, id> *attrInfo = [self _infoForAttrID:attrID];
    NSString *fullTitle = attrInfo[@"fullTitle"];
    return fullTitle;
}

+ (NSString *)briefTitleWithAttrID:(SPLKAttrIdentifier)attrID {
    NSDictionary<NSString *, id> *attrInfo = [self _infoForAttrID:attrID];
    NSString *briefTitle = attrInfo[@"briefTitle"];
    if (!briefTitle) {
        briefTitle = attrInfo[@"fullTitle"];
    }
    return briefTitle;
}

+ (SEL)getterWithAttrID:(SPLKAttrIdentifier)attrID {
    NSDictionary<NSString *, id> *attrInfo = [self _infoForAttrID:attrID];
    NSString *getterString = attrInfo[@"getterString"];
    if (getterString && getterString.length == 0) {
        // 空字符串，比如 image_open_open
        return nil;
    }
    if (!getterString) {
        NSString *fullTitle = attrInfo[@"fullTitle"];
        NSAssert(fullTitle.length > 0, @"");
        
        getterString = [NSString stringWithFormat:@"%@%@", [fullTitle substringToIndex:1].lowercaseString, [fullTitle substringFromIndex:1]].copy;
    }
    return NSSelectorFromString(getterString);
}

+ (SEL)setterWithAttrID:(SPLKAttrIdentifier)attrID {
    NSDictionary<NSString *, id> *attrInfo = [self _infoForAttrID:attrID];
    NSString *setterString = attrInfo[@"setterString"];
    if ([setterString isEqualToString:@""]) {
        // 该属性不可在 Lookin 客户端中被修改
        return nil;
    }
    if (!setterString) {
        NSString *fullTitle = attrInfo[@"fullTitle"];
        NSAssert(fullTitle.length > 0, @"");
        
        setterString = [NSString stringWithFormat:@"set%@%@:", [fullTitle substringToIndex:1].uppercaseString, [fullTitle substringFromIndex:1]];
    }
    return NSSelectorFromString(setterString);
}

+ (BOOL)hideIfNilWithAttrID:(SPLKAttrIdentifier)attrID {
    NSDictionary<NSString *, id> *attrInfo = [self _infoForAttrID:attrID];
    NSNumber *boolValue = attrInfo[@"hideIfNil"];
    return boolValue.boolValue;
}

+ (NSInteger)minAvailableOSVersionWithAttrID:(SPLKAttrIdentifier)attrID {
    NSDictionary<NSString *, id> *attrInfo = [self _infoForAttrID:attrID];
    NSNumber *minVerNum = attrInfo[@"osVersion"];
    NSInteger minVer = [minVerNum integerValue];
    return minVer;
}

@end

#endif /* SHOULD_COMPILE_SPLK_SHARED */
