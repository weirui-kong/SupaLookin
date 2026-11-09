#ifdef SHOULD_COMPILE_SPLK_SHARED 

//
//  SPLKDisplayInfo.h
//  WeRead
//
//  Created by Li Kai on 2018/10/22.
//  Copyright © 2018年 tencent. All rights reserved.
//



#import "SPLKDefines.h"
#import "TargetConditionals.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#elif TARGET_OS_MAC
#import <Appkit/Appkit.h>
#endif

@class SPLKDisplayItem, SPLKAttributesGroup, SPLKAppInfo;

@interface SPLKHierarchyInfo : NSObject <NSSecureCoding, NSCopying>

#if TARGET_OS_IPHONE

/// version 可能为 nil，此时说明 Client 版本号 < 1.0.4
+ (instancetype)staticInfoWithSPLKVersion:(NSString *)version;

+ (instancetype)exportedInfo;

#endif

/// 这里其实就是顶端的那几个 UIWindow
@property(nonatomic, copy) NSArray<SPLKDisplayItem *> *displayItems;

@property(nonatomic, copy) NSDictionary<NSString *, id> *colorAlias;

@property(nonatomic, copy) NSArray<NSString *> *collapsedClassList;

@property(nonatomic, strong) SPLKAppInfo *appInfo;

@property(nonatomic, assign) int serverVersion;

@end

#endif /* SHOULD_COMPILE_SPLK_SHARED */
