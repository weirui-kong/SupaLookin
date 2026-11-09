#ifdef SHOULD_COMPILE_SPLK_SHARED 

//
//  SPLKDisplayInfo.m
//  WeRead
//
//  Created by Li Kai on 2018/10/22.
//  Copyright © 2018年 tencent. All rights reserved.
//

#import <objc/runtime.h>
#import "SPLKHierarchyInfo.h"
#import "SPLKAttributesGroup.h"
#import "SPLKDisplayItem.h"
#import "SPLKAppInfo.h"
#import "NSArray+SPLK.h"
#import "NSString+SPLK.h"

#if TARGET_OS_IPHONE
#import "SPLKHierarchyDisplayItemsMaker.h"
#import "SPLKConfigManager.h"
#import "SPLKCustomAttrSetterManager.h"
#endif

@implementation SPLKHierarchyInfo

#if TARGET_OS_IPHONE

+ (instancetype)staticInfoWithSPLKVersion:(NSString *)version {
    BOOL readCustomInfo = NO;
    // Client 1.0.4 开始支持 customInfo
    if (version && [version splk_numbericOSVersion] >= 10004) {
        readCustomInfo = YES;
    }
    
    [[SPLKCustomAttrSetterManager sharedInstance] removeAll];
    
    SPLKHierarchyInfo *info = [SPLKHierarchyInfo new];
    info.serverVersion = SPLK_DOCUMENT_VERSION;
    info.displayItems = [SPLKHierarchyDisplayItemsMaker itemsWithScreenshots:NO attrList:NO lowImageQuality:NO readCustomInfo:readCustomInfo saveCustomSetter:YES];
    info.appInfo = [SPLKAppInfo currentInfoWithScreenshot:NO icon:YES localIdentifiers:nil];
    info.collapsedClassList = [SPLKConfigManager collapsedClassList];
    info.colorAlias = [SPLKConfigManager colorAlias];
    return info;
}

+ (instancetype)exportedInfo {
    SPLKHierarchyInfo *info = [SPLKHierarchyInfo new];
    info.serverVersion = SPLK_DOCUMENT_VERSION;
    info.displayItems = [SPLKHierarchyDisplayItemsMaker itemsWithScreenshots:YES attrList:YES lowImageQuality:YES readCustomInfo:YES saveCustomSetter:NO];
    info.appInfo = [SPLKAppInfo currentInfoWithScreenshot:NO icon:YES localIdentifiers:nil];
    info.collapsedClassList = [SPLKConfigManager collapsedClassList];
    info.colorAlias = [SPLKConfigManager colorAlias];
    return info;
}

#endif

#pragma mark - <NSSecureCoding>

static NSString * const SPLKHierarchyInfoCodingKey_DisplayItems = @"1";
static NSString * const SPLKHierarchyInfoCodingKey_AppInfo = @"2";
static NSString * const SPLKHierarchyInfoCodingKey_ColorAlias = @"3";
static NSString * const SPLKHierarchyInfoCodingKey_CollapsedClassList = @"4";

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.displayItems forKey:SPLKHierarchyInfoCodingKey_DisplayItems];
    [aCoder encodeObject:self.colorAlias forKey:SPLKHierarchyInfoCodingKey_ColorAlias];
    [aCoder encodeObject:self.collapsedClassList forKey:SPLKHierarchyInfoCodingKey_CollapsedClassList];
    [aCoder encodeObject:self.appInfo forKey:SPLKHierarchyInfoCodingKey_AppInfo];
    [aCoder encodeInt:self.serverVersion forKey:@"serverVersion"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        self.displayItems = [aDecoder decodeObjectForKey:SPLKHierarchyInfoCodingKey_DisplayItems];
        self.colorAlias = [aDecoder decodeObjectForKey:SPLKHierarchyInfoCodingKey_ColorAlias];
        self.collapsedClassList = [aDecoder decodeObjectForKey:SPLKHierarchyInfoCodingKey_CollapsedClassList];
        self.appInfo = [aDecoder decodeObjectForKey:SPLKHierarchyInfoCodingKey_AppInfo];
        self.serverVersion = [aDecoder decodeIntForKey:@"serverVersion"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

#pragma mark - <NSCopying>

- (id)copyWithZone:(NSZone *)zone {
    SPLKHierarchyInfo *newAppInfo = [[SPLKHierarchyInfo allocWithZone:zone] init];
    newAppInfo.serverVersion = self.serverVersion;
    newAppInfo.appInfo = self.appInfo.copy;
    newAppInfo.collapsedClassList = self.collapsedClassList;
    newAppInfo.colorAlias = self.colorAlias;
    newAppInfo.displayItems = [self.displayItems splk_map:^id(NSUInteger idx, SPLKDisplayItem *oldItem) {
        return oldItem.copy;
    }];
    
    return newAppInfo;
}

@end

#endif /* SHOULD_COMPILE_SPLK_SHARED */
