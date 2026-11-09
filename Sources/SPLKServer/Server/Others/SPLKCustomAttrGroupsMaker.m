#ifdef SHOULD_COMPILE_SPLK_SERVER
//
//  SPLKCustomAttrGroupsMaker.m
//  SPLKServer
//
//  Created by LikaiMacStudioWork on 2023/10/31.
//

#import "SPLKCustomAttrGroupsMaker.h"
#import "SPLKAttrGroupsMaker.h"
#import "SPLKAttributesGroup.h"
#import "SPLKAttributesSection.h"
#import "SPLKAttribute.h"
#import "SPLKDashboardBlueprint.h"
#import "SPLKIvarTrace.h"
#import "UIColor+SPLKServer.h"
#import "SPLKServerDefines.h"
#import "SPLKCustomAttrSetterManager.h"

@interface SPLKCustomAttrGroupsMaker ()

/// key 是 section title
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<SPLKAttribute *> *> *sectionAndAttrs;

@property(nonatomic, copy) NSString *resolvedCustomDisplayTitle;
@property(nonatomic, copy) NSString *resolvedDanceUISource;
@property(nonatomic, strong) NSMutableArray *resolvedGroups;

@property(nonatomic, weak) CALayer *layer;

@end

@implementation SPLKCustomAttrGroupsMaker

- (instancetype)initWithLayer:(CALayer *)layer {
    if (self = [super init]) {
        self.sectionAndAttrs = [NSMutableDictionary dictionary];
        self.layer = layer;
    }
    return self;
}

- (void)execute {
    if (!self.layer) {
        NSAssert(NO, @"");
        return;
    }
    NSMutableArray<NSString *> *selectors = [NSMutableArray array];
    [selectors addObject:@"splk_customDebugInfos"];
    for (int i = 0; i < 5; i++) {
        [selectors addObject:[NSString stringWithFormat:@"splk_customDebugInfos_%@", @(i)]];
    }
    
    for (NSString *name in selectors) {
        [self makeAttrsForViewOrLayer:self.layer selectorName:name];
        
        UIView *view = self.layer.splk_hostView;
        if (view) {
            [self makeAttrsForViewOrLayer:view selectorName:name];
        }
    }
    
    if ([self.sectionAndAttrs count] == 0) {
        return;
    }
    NSMutableArray<SPLKAttributesGroup *> *groups = [NSMutableArray array];
    [self.sectionAndAttrs enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull groupTitle, NSMutableArray<SPLKAttribute *> * _Nonnull attrs, BOOL * _Nonnull stop) {
        SPLKAttributesGroup *group = [SPLKAttributesGroup new];
        group.userCustomTitle = groupTitle;
        group.identifier = SPLKAttrGroup_UserCustom;
        
        NSMutableArray<SPLKAttributesSection *> *sections = [NSMutableArray array];
        [attrs enumerateObjectsUsingBlock:^(SPLKAttribute * _Nonnull attr, NSUInteger idx, BOOL * _Nonnull stop) {
            SPLKAttributesSection *sec = [SPLKAttributesSection new];
            sec.identifier = SPLKAttrSec_UserCustom;
            sec.attributes = @[attr];
            [sections addObject:sec];
        }];
        
        group.attrSections = sections;
        [groups addObject:group];
    }];
    [groups sortedArrayUsingComparator:^NSComparisonResult(SPLKAttributesGroup *obj1, SPLKAttributesGroup *obj2) {
        return [obj1.userCustomTitle compare:obj2.userCustomTitle];
    }];
    
    self.resolvedGroups = groups;
}

- (void)makeAttrsForViewOrLayer:(id)viewOrLayer selectorName:(NSString *)selectorName {
    if (!viewOrLayer || !selectorName.length) {
        return;
    }
    if (![viewOrLayer isKindOfClass:[UIView class]] && ![viewOrLayer isKindOfClass:[CALayer class]]) {
        return;
    }
    SEL selector = NSSelectorFromString(selectorName);
    if (![viewOrLayer respondsToSelector:selector]) {
        return;
    }
    NSMethodSignature *signature = [viewOrLayer methodSignatureForSelector:selector];
    if (signature.numberOfArguments > 2) {
        NSAssert(NO, @"SPLKServer - There should be no explicit parameters.");
        return;
    }
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:viewOrLayer];
    [invocation setSelector:selector];
    [invocation invoke];
    
    // 小心这里的内存管理
    NSDictionary<NSString *, id> * __unsafe_unretained tempRawData;
    [invocation getReturnValue:&tempRawData];
    if (!tempRawData || ![tempRawData isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    NSDictionary<NSString *, id> *rawData = tempRawData;
    NSArray *rawProperties = rawData[@"properties"];
    
    NSString *customTitle = rawData[@"title"];
    if (customTitle && [customTitle isKindOfClass:[NSString class]] && customTitle.length > 0) {
        self.resolvedCustomDisplayTitle = customTitle;
    }
    
    NSString *danceSource = rawData[@"splk_source"];
    if (danceSource && [danceSource isKindOfClass:[NSString class]] && danceSource.length > 0) {
        self.resolvedDanceUISource = danceSource;
    }
    
    [self makeAttrsFromRawProperties:rawProperties];
}

- (void)makeAttrsFromRawProperties:(NSArray *)rawProperties {
    if (!rawProperties || ![rawProperties isKindOfClass:[NSArray class]]) {
        return;
    }
    
    for (NSDictionary<NSString *, id> *dict in rawProperties) {
        NSString *groupTitle;
        SPLKAttribute *attr = [SPLKCustomAttrGroupsMaker attrFromRawDict:dict saveCustomSetter:YES groupTitle:&groupTitle];
        if (!attr) {
            continue;
        }
        if (!self.sectionAndAttrs[groupTitle]) {
            self.sectionAndAttrs[groupTitle] = [NSMutableArray array];
        }
        [self.sectionAndAttrs[groupTitle] addObject:attr];
    }
}

+ (SPLKAttribute *)attrFromRawDict:(NSDictionary *)dict saveCustomSetter:(BOOL)saveCustomSetter groupTitle:(inout NSString **)inoutGroupTitle {
    SPLKAttribute *attr = [SPLKAttribute new];
    attr.identifier = SPLKAttr_UserCustom;
    
    NSString *title = dict[@"title"];
    NSString *type = dict[@"valueType"];
    NSString *section = dict[@"section"];
    id value = dict[@"value"];
    
    if (!title || ![title isKindOfClass:[NSString class]]) {
        NSLog(@"SPLKServer - Wrong title");
        return nil;
    }
    if (!type || ![type isKindOfClass:[NSString class]]) {
        NSLog(@"SPLKServer - Wrong valueType");
        return nil;
    }
    if (!section || ![section isKindOfClass:[NSString class]] || section.length == 0) {
        *inoutGroupTitle = @"Custom";
    } else {
        *inoutGroupTitle = section;
    }
    
    attr.displayTitle = title;
    
    NSString *fixedType = type.lowercaseString;
    if ([fixedType isEqualToString:@"string"]) {
        if (value != nil && ![value isKindOfClass:[NSString class]]) {
            // nil 是合法的
            NSLog(@"SPLKServer - Wrong value type.");
            return nil;
        }
        attr.attrType = SPLKAttrTypeNSString;
        attr.value = value;
        
        if (saveCustomSetter && dict[@"retainedSetter"]) {
            NSString *uniqueID = [[NSUUID new] UUIDString];
            SPLKStringSetter setter = dict[@"retainedSetter"];
            [[SPLKCustomAttrSetterManager sharedInstance] saveStringSetter:setter uniqueID:uniqueID];
            attr.customSetterID = uniqueID;
        }
        
        return attr;
    }
    
    if ([fixedType isEqualToString:@"number"]) {
        if (value == nil) {
            NSLog(@"SPLKServer - No value.");
            return nil;
        }
        if (![value isKindOfClass:[NSNumber class]]) {
            NSLog(@"SPLKServer - Wrong value type.");
            return nil;
        }
        attr.attrType = SPLKAttrTypeDouble;
        attr.value = value;
        
        if (saveCustomSetter && dict[@"retainedSetter"]) {
            NSString *uniqueID = [[NSUUID new] UUIDString];
            SPLKNumberSetter setter = dict[@"retainedSetter"];
            [[SPLKCustomAttrSetterManager sharedInstance] saveNumberSetter:setter uniqueID:uniqueID];
            attr.customSetterID = uniqueID;
        }
        
        return attr;
    }
        
    if ([fixedType isEqualToString:@"bool"]) {
        if (value == nil) {
            NSLog(@"SPLKServer - No value.");
            return nil;
        }
        if (![value isKindOfClass:[NSNumber class]]) {
            NSLog(@"SPLKServer - Wrong value type.");
            return nil;
        }
        attr.attrType = SPLKAttrTypeBOOL;
        attr.value = value;
        
        if (saveCustomSetter && dict[@"retainedSetter"]) {
            NSString *uniqueID = [[NSUUID new] UUIDString];
            SPLKBoolSetter setter = dict[@"retainedSetter"];
            [[SPLKCustomAttrSetterManager sharedInstance] saveBoolSetter:setter uniqueID:uniqueID];
            attr.customSetterID = uniqueID;
        }
        
        return attr;
    }
    
    if ([fixedType isEqualToString:@"color"]) {
        if (value != nil && ![value isKindOfClass:[UIColor class]]) {
            // nil 是合法的
            NSLog(@"SPLKServer - Wrong value type.");
            return nil;
        }
        attr.attrType = SPLKAttrTypeUIColor;
        attr.value = [(UIColor *)value splk_rgbaComponents];
        
        if (saveCustomSetter && dict[@"retainedSetter"]) {
            NSString *uniqueID = [[NSUUID new] UUIDString];
            SPLKColorSetter setter = dict[@"retainedSetter"];
            [[SPLKCustomAttrSetterManager sharedInstance] saveColorSetter:setter uniqueID:uniqueID];
            attr.customSetterID = uniqueID;
        }
        
        return attr;
    }
    
    if ([fixedType isEqualToString:@"rect"]) {
        if (value == nil) {
            NSLog(@"SPLKServer - No value.");
            return nil;
        }
        if (![value isKindOfClass:[NSValue class]]) {
            NSLog(@"SPLKServer - Wrong value type.");
            return nil;
        }
        attr.attrType = SPLKAttrTypeCGRect;
        attr.value = value;
        
        if (saveCustomSetter && dict[@"retainedSetter"]) {
            NSString *uniqueID = [[NSUUID new] UUIDString];
            SPLKRectSetter setter = dict[@"retainedSetter"];
            [[SPLKCustomAttrSetterManager sharedInstance] saveRectSetter:setter uniqueID:uniqueID];
            attr.customSetterID = uniqueID;
        }
        
        return attr;
    }
    
    if ([fixedType isEqualToString:@"size"]) {
        if (value == nil) {
            NSLog(@"SPLKServer - No value.");
            return nil;
        }
        if (![value isKindOfClass:[NSValue class]]) {
            NSLog(@"SPLKServer - Wrong value type.");
            return nil;
        }
        attr.attrType = SPLKAttrTypeCGSize;
        attr.value = value;
        
        if (saveCustomSetter && dict[@"retainedSetter"]) {
            NSString *uniqueID = [[NSUUID new] UUIDString];
            SPLKSizeSetter setter = dict[@"retainedSetter"];
            [[SPLKCustomAttrSetterManager sharedInstance] saveSizeSetter:setter uniqueID:uniqueID];
            attr.customSetterID = uniqueID;
        }
        
        return attr;
    }
    
    if ([fixedType isEqualToString:@"point"]) {
        if (value == nil) {
            NSLog(@"SPLKServer - No value.");
            return nil;
        }
        if (![value isKindOfClass:[NSValue class]]) {
            NSLog(@"SPLKServer - Wrong value type.");
            return nil;
        }
        attr.attrType = SPLKAttrTypeCGPoint;
        attr.value = value;
        
        if (saveCustomSetter && dict[@"retainedSetter"]) {
            NSString *uniqueID = [[NSUUID new] UUIDString];
            SPLKPointSetter setter = dict[@"retainedSetter"];
            [[SPLKCustomAttrSetterManager sharedInstance] savePointSetter:setter uniqueID:uniqueID];
            attr.customSetterID = uniqueID;
        }
        
        return attr;
    }
    
    if ([fixedType isEqualToString:@"insets"]) {
        if (value == nil) {
            NSLog(@"SPLKServer - No value.");
            return nil;
        }
        if (![value isKindOfClass:[NSValue class]]) {
            NSLog(@"SPLKServer - Wrong value type.");
            return nil;
        }
        attr.attrType = SPLKAttrTypeUIEdgeInsets;
        attr.value = value;
        
        if (saveCustomSetter && dict[@"retainedSetter"]) {
            NSString *uniqueID = [[NSUUID new] UUIDString];
            SPLKInsetsSetter setter = dict[@"retainedSetter"];
            [[SPLKCustomAttrSetterManager sharedInstance] saveInsetsSetter:setter uniqueID:uniqueID];
            attr.customSetterID = uniqueID;
        }
        
        return attr;
    }
    
    if ([fixedType isEqualToString:@"shadow"]) {
        if (value == nil) {
            NSLog(@"SPLKServer - No value.");
            return nil;
        }
        if (![value isKindOfClass:[NSDictionary class]]) {
            NSLog(@"SPLKServer - Wrong value type.");
            return nil;
        }
        NSDictionary *shadowInfo = value;
        if (![shadowInfo[@"offset"] isKindOfClass:[NSValue class]]) {
            NSLog(@"SPLKServer - Wrong value. No offset.");
            return nil;
        }
        if (![shadowInfo[@"opacity"] isKindOfClass:[NSNumber class]]) {
            NSLog(@"SPLKServer - Wrong value. No opacity.");
            return nil;
        }
        if (![shadowInfo[@"radius"] isKindOfClass:[NSNumber class]]) {
            NSLog(@"SPLKServer - Wrong value. No radius.");
            return nil;
        }
        NSMutableDictionary *checkedShadowInfo = [@{
            @"offset": shadowInfo[@"offset"],
            @"opacity": shadowInfo[@"opacity"],
            @"radius": shadowInfo[@"radius"]
        } mutableCopy];
        if ([shadowInfo[@"color"] isKindOfClass:[UIColor class]]) {
            checkedShadowInfo[@"color"] = [(UIColor *)shadowInfo[@"color"] splk_rgbaComponents];
        }
        
        attr.attrType = SPLKAttrTypeShadow;
        attr.value = checkedShadowInfo;
        
        return attr;
    }
    
    if ([fixedType isEqualToString:@"enum"]) {
        if (value == nil) {
            NSLog(@"SPLKServer - No value.");
            return nil;
        }
        if (![value isKindOfClass:[NSString class]]) {
            NSLog(@"SPLKServer - Wrong value type.");
            return nil;
        }
        attr.attrType = SPLKAttrTypeEnumString;
        attr.value = value;
        
        NSArray<NSString *> *allEnumCases = dict[@"allEnumCases"];
        if ([allEnumCases isKindOfClass:[NSArray class]]) {
            attr.extraValue = allEnumCases;
        }
        
        if (saveCustomSetter && dict[@"retainedSetter"]) {
            NSString *uniqueID = [[NSUUID new] UUIDString];
            SPLKEnumSetter setter = dict[@"retainedSetter"];
            [[SPLKCustomAttrSetterManager sharedInstance] saveEnumSetter:setter uniqueID:uniqueID];
            attr.customSetterID = uniqueID;
        }
        
        return attr;
    }
    
    if ([fixedType isEqualToString:@"json"]) {
        if (![value isKindOfClass:[NSString class]]) {
            NSLog(@"SPLKServer - Wrong value type.");
            return nil;
        }
        attr.attrType = SPLKAttrTypeJson;
        attr.value = value;
        
        return attr;
    }
    
    NSLog(@"SPLKServer - Unsupported value type.");
    return nil;
}

- (NSArray<SPLKAttributesGroup *> *)getGroups {
    return self.resolvedGroups;
}

- (NSString *)getCustomDisplayTitle {
    return self.resolvedCustomDisplayTitle;
}

- (NSString *)getDanceUISource {
    return self.resolvedDanceUISource;
}

+ (NSArray<SPLKAttributesGroup *> *)makeGroupsFromRawProperties:(NSArray *)rawProperties saveCustomSetter:(BOOL)saveCustomSetter {
    if (!rawProperties || ![rawProperties isKindOfClass:[NSArray class]]) {
        return nil;
    }
    // key 是 group title
    NSMutableDictionary<NSString *, NSMutableArray<SPLKAttribute *> *> *groupTitleAndAttrs = [NSMutableDictionary dictionary];
    
    for (NSDictionary<NSString *, id> *dict in rawProperties) {
        NSString *groupTitle;
        SPLKAttribute *attr = [SPLKCustomAttrGroupsMaker attrFromRawDict:dict saveCustomSetter:saveCustomSetter groupTitle:&groupTitle];
        if (!attr) {
            continue;
        }
        if (!groupTitleAndAttrs[groupTitle]) {
            groupTitleAndAttrs[groupTitle] = [NSMutableArray array];
        }
        [groupTitleAndAttrs[groupTitle] addObject:attr];
    }
    
    if ([groupTitleAndAttrs count] == 0) {
        return nil;
    }
    NSMutableArray<SPLKAttributesGroup *> *groups = [NSMutableArray array];
    [groupTitleAndAttrs enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull groupTitle, NSMutableArray<SPLKAttribute *> * _Nonnull attrs, BOOL * _Nonnull stop) {
        SPLKAttributesGroup *group = [SPLKAttributesGroup new];
        group.userCustomTitle = groupTitle;
        group.identifier = SPLKAttrGroup_UserCustom;
        
        NSMutableArray<SPLKAttributesSection *> *sections = [NSMutableArray array];
        [attrs enumerateObjectsUsingBlock:^(SPLKAttribute * _Nonnull attr, NSUInteger idx, BOOL * _Nonnull stop) {
            SPLKAttributesSection *sec = [SPLKAttributesSection new];
            sec.identifier = SPLKAttrSec_UserCustom;
            sec.attributes = @[attr];
            [sections addObject:sec];
        }];
        
        group.attrSections = sections;
        [groups addObject:group];
    }];
    [groups sortedArrayUsingComparator:^NSComparisonResult(SPLKAttributesGroup *obj1, SPLKAttributesGroup *obj2) {
        return [obj1.userCustomTitle compare:obj2.userCustomTitle];
    }];
    return [groups copy];
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
