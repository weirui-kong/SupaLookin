#ifdef SHOULD_COMPILE_SPLK_SERVER 

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

#endif /* SHOULD_COMPILE_SPLK_SERVER */
