//
//  SPLKAttrIdentifiers.h
//  Lookin
//
//  Created by Li Kai on 2018/12/1.
//  https://lookin.work
//

/// 注意：新属性只能加到末尾，否则新旧版本搭配时可能有兼容问题
typedef NS_ENUM(NSInteger, SPLKAttrType) {
    SPLKAttrTypeNone,
    SPLKAttrTypeVoid,
    SPLKAttrTypeChar,
    SPLKAttrTypeInt,
    SPLKAttrTypeShort,
    SPLKAttrTypeLong,
    SPLKAttrTypeLongLong,
    SPLKAttrTypeUnsignedChar,
    SPLKAttrTypeUnsignedInt,
    SPLKAttrTypeUnsignedShort,
    SPLKAttrTypeUnsignedLong,
    SPLKAttrTypeUnsignedLongLong,
    SPLKAttrTypeFloat,
    SPLKAttrTypeDouble,
    SPLKAttrTypeBOOL,
    SPLKAttrTypeSel,
    SPLKAttrTypeClass,
    SPLKAttrTypeCGPoint,
    SPLKAttrTypeCGVector,
    SPLKAttrTypeCGSize,
    SPLKAttrTypeCGRect,
    SPLKAttrTypeCGAffineTransform,
    SPLKAttrTypeUIEdgeInsets,
    SPLKAttrTypeUIOffset,
    SPLKAttrTypeNSString,
    SPLKAttrTypeEnumInt,
    SPLKAttrTypeEnumLong,
    /// value 实际为 RGBA 数组，即 @[NSNumber, NSNumber, NSNumber, NSNumber]，NSNumber 范围是 0 ~ 1
    SPLKAttrTypeUIColor,
    /// 业务需要根据具体的 AttrIdentifier 来解析
    SPLKAttrTypeCustomObj,
    
    SPLKAttrTypeEnumString,
    SPLKAttrTypeShadow,
    SPLKAttrTypeJson
};
