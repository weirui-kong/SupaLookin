#ifdef SHOULD_COMPILE_SPLK_SERVER 

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

#endif /* SHOULD_COMPILE_SPLK_SERVER */
