#ifdef SHOULD_COMPILE_SPLK_SERVER
//
//  SPLKCustomAttrModificationHandler.m
//  SPLKServer
//
//  Created by likaimacbookhome on 2023/11/4.
//

#import "SPLKCustomAttrModificationHandler.h"
#import "SPLKCustomAttrSetterManager.h"
#import "UIColor+SPLKServer.h"

@implementation SPLKCustomAttrModificationHandler

+ (BOOL)handleModification:(SPLKCustomAttrModification *)modification {
    if (!modification || modification.customSetterID.length == 0) {
        return NO;
    }
    switch (modification.attrType) {
        case SPLKAttrTypeNSString: {
            NSString *newValue = modification.value;
            if (newValue != nil && ![newValue isKindOfClass:[NSString class]]) {
                // nil 是合法的
                return NO;
            }
            SPLKStringSetter setter = [[SPLKCustomAttrSetterManager sharedInstance] getStringSetterWithID:modification.customSetterID];
            if (!setter) {
                return NO;
            }
            setter(newValue);
            return YES;
        }
            
        case SPLKAttrTypeDouble: {
            NSNumber *newValue = modification.value;
            if (![newValue isKindOfClass:[NSNumber class]]) {
                return NO;
            }
            SPLKNumberSetter setter = [[SPLKCustomAttrSetterManager sharedInstance] getNumberSetterWithID:modification.customSetterID];
            if (!setter) {
                return NO;
            }
            setter(newValue);
            return YES;
        }
            
        case SPLKAttrTypeBOOL: {
            NSNumber *newValue = modification.value;
            if (![newValue isKindOfClass:[NSNumber class]]) {
                return NO;
            }
            SPLKBoolSetter setter = [[SPLKCustomAttrSetterManager sharedInstance] getBoolSetterWithID:modification.customSetterID];
            if (!setter) {
                return NO;
            }
            setter(newValue.boolValue);
            return YES;
        }
        
        case SPLKAttrTypeUIColor: {
            SPLKColorSetter setter = [[SPLKCustomAttrSetterManager sharedInstance] getColorSetterWithID:modification.customSetterID];
            if (!setter) {
                return NO;
            }
            
            NSArray<NSNumber *> *newValue = modification.value;
            if (newValue == nil) {
                // nil 是合法的
                setter(nil);
                return YES;
            }
            if (![newValue isKindOfClass:[NSArray class]]) {
                return NO;
            }
            UIColor *color = [UIColor splk_colorFromRGBAComponents:newValue];
            if (!color) {
                return NO;
            }
            setter(color);
            return YES;
        }
            
        case SPLKAttrTypeEnumString: {
            NSString *newValue = modification.value;
            if (![newValue isKindOfClass:[NSString class]]) {
                return NO;
            }
            SPLKEnumSetter setter = [[SPLKCustomAttrSetterManager sharedInstance] getEnumSetterWithID:modification.customSetterID];
            if (!setter) {
                return NO;
            }
            setter(newValue);
            return YES;
        }
            
        case SPLKAttrTypeCGRect: {
            NSValue *newValue = modification.value;
            if (![newValue isKindOfClass:[NSValue class]]) {
                return NO;
            }
            SPLKRectSetter setter = [[SPLKCustomAttrSetterManager sharedInstance] getRectSetterWithID:modification.customSetterID];
            if (!setter) {
                return NO;
            }
            setter(newValue.CGRectValue);
            return YES;
        }
            
        case SPLKAttrTypeCGSize: {
            NSValue *newValue = modification.value;
            if (![newValue isKindOfClass:[NSValue class]]) {
                return NO;
            }
            SPLKSizeSetter setter = [[SPLKCustomAttrSetterManager sharedInstance] getSizeSetterWithID:modification.customSetterID];
            if (!setter) {
                return NO;
            }
            setter(newValue.CGSizeValue);
            return YES;
        }
            
        case SPLKAttrTypeCGPoint: {
            NSValue *newValue = modification.value;
            if (![newValue isKindOfClass:[NSValue class]]) {
                return NO;
            }
            SPLKPointSetter setter = [[SPLKCustomAttrSetterManager sharedInstance] getPointSetterWithID:modification.customSetterID];
            if (!setter) {
                return NO;
            }
            setter(newValue.CGPointValue);
            return YES;
        }
            
        case SPLKAttrTypeUIEdgeInsets: {
            NSValue *newValue = modification.value;
            if (![newValue isKindOfClass:[NSValue class]]) {
                return NO;
            }
            SPLKInsetsSetter setter = [[SPLKCustomAttrSetterManager sharedInstance] getInsetsSetterWithID:modification.customSetterID];
            if (!setter) {
                return NO;
            }
            setter(newValue.UIEdgeInsetsValue);
            return YES;
        }
            
        default:
            return NO;
    }
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
