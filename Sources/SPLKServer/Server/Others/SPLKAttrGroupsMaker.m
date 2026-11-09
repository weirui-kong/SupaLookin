#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  SPLKAttrGroupsMaker.m
//  SPLKServer
//
//  Created by Li Kai on 2019/6/6.
//  https://lookin.work
//

#import "SPLKAttrGroupsMaker.h"
#import "SPLKAttributesGroup.h"
#import "SPLKAttributesSection.h"
#import "SPLKAttribute.h"
#import "SPLKDashboardBlueprint.h"
#import "SPLKIvarTrace.h"
#import "UIColor+SPLKServer.h"
#import "SPLKServerDefines.h"

@implementation SPLKAttrGroupsMaker

+ (NSArray<SPLKAttributesGroup *> *)attrGroupsForLayer:(CALayer *)layer {
    if (!layer) {
        NSAssert(NO, @"");
        return nil;
    }
    NSArray<SPLKAttributesGroup *> *groups = [[SPLKDashboardBlueprint groupIDs] splk_map:^id(NSUInteger idx, SPLKAttrGroupIdentifier groupID) {
        SPLKAttributesGroup *group = [SPLKAttributesGroup new];
        group.identifier = groupID;

        NSArray<SPLKAttrSectionIdentifier> *secIDs = [SPLKDashboardBlueprint sectionIDsForGroupID:groupID];
        group.attrSections = [secIDs splk_map:^id(NSUInteger idx, SPLKAttrSectionIdentifier secID) {
            SPLKAttributesSection *sec = [SPLKAttributesSection new];
            sec.identifier = secID;
            
            NSArray<SPLKAttrIdentifier> *attrIDs = [SPLKDashboardBlueprint attrIDsForSectionID:secID];
            sec.attributes = [attrIDs splk_map:^id(NSUInteger idx, SPLKAttrIdentifier attrID) {
                NSInteger minAvailableVersion = [SPLKDashboardBlueprint minAvailableOSVersionWithAttrID:attrID];
                if (minAvailableVersion > 0 && (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion < minAvailableVersion)) {
                    // iOS 版本过低不支持该属性
                    return nil;
                }
                
                id targetObj = nil;
                if ([SPLKDashboardBlueprint isUIViewPropertyWithAttrID:attrID]) {
                    targetObj = layer.splk_hostView;
                } else {
                    targetObj = layer;
                }
                
                if (targetObj) {
                    Class targetClass = NSClassFromString([SPLKDashboardBlueprint classNameWithAttrID:attrID]);
                    if (![targetObj isKindOfClass:targetClass]) {
                        return nil;
                    }
                    
                    SPLKAttribute *attr = [self _attributeWithIdentifer:attrID targetObject:targetObj];
                    return attr;
                } else {
                    return nil;
                }
            }];
            
            if (sec.attributes.count) {
                return sec;
            } else {
                return nil;
            }
        }];
        
        if ([groupID isEqualToString:SPLKAttrGroup_AutoLayout]) {
            // 这里特殊处理一下，如果 AutoLayout 里面不包含 Constraints 的话（只有 Hugging 和 Resistance），就丢弃掉这整个 AutoLayout 不显示
            BOOL hasConstraits = [group.attrSections splk_any:^BOOL(SPLKAttributesSection *obj) {
                return [obj.identifier isEqualToString:SPLKAttrSec_AutoLayout_Constraints];
            }];
            if (!hasConstraits) {
                return nil;
            }
        }
        
        if (group.attrSections.count) {
            return group;
        } else {
            return nil;
        }
    }];
    
    return groups;
}

+ (SPLKAttribute *)_attributeWithIdentifer:(SPLKAttrIdentifier)identifier targetObject:(id)target {
    if (!target) {
        NSAssert(NO, @"");
        return nil;
    }
    
    SPLKAttribute *attribute = [SPLKAttribute new];
    attribute.identifier = identifier;
    
    SEL getter = [SPLKDashboardBlueprint getterWithAttrID:identifier];
    if (!getter) {
        NSAssert(NO, @"");
        return nil;
    }
    if (![target respondsToSelector:getter]) {
        // 比如某些 QMUI 的属性，不引入 QMUI 就会走到这个分支里
        return nil;
    }
    NSMethodSignature *signature = [target methodSignatureForSelector:getter];
    if (signature.numberOfArguments > 2) {
        NSAssert(NO, @"getter 不可以有参数");
        return nil;
    }
    if (strcmp([signature methodReturnType], @encode(void)) == 0) {
        NSAssert(NO, @"getter 返回值不能为 void");
        return nil;
    }
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = target;
    invocation.selector = getter;
    [invocation invoke];
    
    const char *returnType = [signature methodReturnType];
    
    if (strcmp(returnType, @encode(char)) == 0) {
        char targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeChar;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(int)) == 0) {
        int targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.value = @(targetValue);
        if ([SPLKDashboardBlueprint enumListNameWithAttrID:identifier]) {
            attribute.attrType = SPLKAttrTypeEnumInt;
        } else {
            attribute.attrType = SPLKAttrTypeInt;
        }
        
    } else if (strcmp(returnType, @encode(short)) == 0) {
        short targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeShort;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(long)) == 0) {
        long targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.value = @(targetValue);
        if ([SPLKDashboardBlueprint enumListNameWithAttrID:identifier]) {
            attribute.attrType = SPLKAttrTypeEnumLong;
        } else {
            attribute.attrType = SPLKAttrTypeLong;
        }
        
    } else if (strcmp(returnType, @encode(long long)) == 0) {
        long long targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeLongLong;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(unsigned char)) == 0) {
        unsigned char targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeUnsignedChar;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(unsigned int)) == 0) {
        unsigned int targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeUnsignedInt;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(unsigned short)) == 0) {
        unsigned short targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeUnsignedShort;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(unsigned long)) == 0) {
        unsigned long targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeUnsignedLong;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(unsigned long long)) == 0) {
        unsigned long long targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeUnsignedLongLong;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(float)) == 0) {
        float targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeFloat;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(double)) == 0) {
        double targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeDouble;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(BOOL)) == 0) {
        BOOL targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeBOOL;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(SEL)) == 0) {
        SEL targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeSel;
        attribute.value = NSStringFromSelector(targetValue);
        
    } else if (strcmp(returnType, @encode(Class)) == 0) {
        Class targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeClass;
        attribute.value = NSStringFromClass(targetValue);
        
    } else if (strcmp(returnType, @encode(CGPoint)) == 0) {
        CGPoint targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeCGPoint;
        attribute.value = [NSValue valueWithCGPoint:targetValue];
        
    } else if (strcmp(returnType, @encode(CGVector)) == 0) {
        CGVector targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeCGVector;
        attribute.value = [NSValue valueWithCGVector:targetValue];
        
    } else if (strcmp(returnType, @encode(CGSize)) == 0) {
        CGSize targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeCGSize;
        attribute.value = [NSValue valueWithCGSize:targetValue];
        
    } else if (strcmp(returnType, @encode(CGRect)) == 0) {
        CGRect targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeCGRect;
        attribute.value = [NSValue valueWithCGRect:targetValue];
        
    } else if (strcmp(returnType, @encode(CGAffineTransform)) == 0) {
        CGAffineTransform targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeCGAffineTransform;
        attribute.value = [NSValue valueWithCGAffineTransform:targetValue];
        
    } else if (strcmp(returnType, @encode(UIEdgeInsets)) == 0) {
        UIEdgeInsets targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeUIEdgeInsets;
        attribute.value = [NSValue valueWithUIEdgeInsets:targetValue];
        
    } else if (strcmp(returnType, @encode(UIOffset)) == 0) {
        UIOffset targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = SPLKAttrTypeUIOffset;
        attribute.value = [NSValue valueWithUIOffset:targetValue];
        
    } else {
        NSString *argType_string = [[NSString alloc] splk_safeInitWithUTF8String:returnType];
        if ([argType_string hasPrefix:@"@"]) {
            __unsafe_unretained id returnObjValue;
            [invocation getReturnValue:&returnObjValue];
            
            if (!returnObjValue && [SPLKDashboardBlueprint hideIfNilWithAttrID:identifier]) {
                // 对于某些属性，若 value 为 nil 则不显示
                return nil;
            }
            
            attribute.attrType = [SPLKDashboardBlueprint objectAttrTypeWithAttrID:identifier];
            if (attribute.attrType == SPLKAttrTypeUIColor) {
                if (returnObjValue == nil) {
                    attribute.value = nil;
                } else if ([returnObjValue isKindOfClass:[UIColor class]] && [returnObjValue respondsToSelector:@selector(splk_rgbaComponents)]) {
                    attribute.value = [returnObjValue splk_rgbaComponents];
                } else {
                    // https://github.com/QMUI/LookinServer/issues/124
                    return nil;
                }
            } else {
                attribute.value = returnObjValue;
            }
            
        } else {
            NSAssert(NO, @"不支持解析该类型的返回值");
            return nil;
        }
    }
    
    return attribute;
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
