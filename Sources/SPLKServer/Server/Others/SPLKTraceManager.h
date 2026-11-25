#import <TargetConditionals.h>
#if TARGET_OS_IPHONE

//
//  SPLKTraceManager.h
//  SPLKServer
//
//  Created by Li Kai on 2019/5/5.
//  https://lookin.work
//



#import <Foundation/Foundation.h>

@class SPLKIvarTrace;

@interface SPLKTraceManager : NSObject

+ (instancetype)sharedInstance;

- (void)reload;

- (void)addSearchTarger:(id)target;

@end

#endif /* TARGET_OS_IPHONE */
