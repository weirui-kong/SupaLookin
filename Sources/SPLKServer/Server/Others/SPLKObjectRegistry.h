#import <TargetConditionals.h>
#if TARGET_OS_IPHONE

//
//  SPLKObjectRegistry.h
//  SPLKServer
//
//  Created by Li Kai on 2019/4/21.
//  https://lookin.work
//

#import <Foundation/Foundation.h>

@interface SPLKObjectRegistry : NSObject

+ (instancetype)sharedInstance;

- (unsigned long)addObject:(NSObject *)object;

- (NSObject *)objectWithOid:(unsigned long)oid;

@end

#endif /* TARGET_OS_IPHONE */
