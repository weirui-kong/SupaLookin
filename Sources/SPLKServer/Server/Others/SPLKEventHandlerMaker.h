#import <TargetConditionals.h>
#if TARGET_OS_IPHONE

//
//  SPLKEventHandlerMaker.h
//  SPLKServer
//
//  Created by Li Kai on 2019/8/7.
//  https://lookin.work
//

#import "SPLKDefines.h"

@class SPLKEventHandler;

@interface SPLKEventHandlerMaker : NSObject

+ (NSArray<SPLKEventHandler *> *)makeForView:(UIView *)view;

@end

#endif /* TARGET_OS_IPHONE */
