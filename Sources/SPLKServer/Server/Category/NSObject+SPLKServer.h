#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  NSObject+SPLKServer.h
//  SPLKServer
//
//  Created by Li Kai on 2019/4/21.
//  https://lookin.work
//

#import "SPLKDefines.h"
#import <Foundation/Foundation.h>

@class SPLKIvarTrace;

@interface NSObject (SPLKServer)

#pragma mark - oid

/// 如果 oid 不存在则会创建新的 oid
- (unsigned long)splk_registerOid;

/// 0 表示不存在
@property(nonatomic, assign) unsigned long splk_oid;

+ (NSObject *)splk_objectWithOid:(unsigned long)oid;

#pragma mark - trace

@property(nonatomic, copy) NSString *splk_specialTrace;

+ (void)splk_clearAllObjectsTraces;

/**
 获取当前对象的 Class 层级树，如 @[@"UIView", @"UIResponder", @"NSObject"]。未 demangle，有 Swift Module Name
 */
- (NSArray<NSString *> *)splk_classChainList;

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
