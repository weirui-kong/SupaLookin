#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  SPLKRequestHandler.h
//  SPLKServer
//
//  Created by Li Kai on 2019/1/15.
//  https://lookin.work
//

#import <Foundation/Foundation.h>

@interface SPLKRequestHandler : NSObject

- (BOOL)canHandleRequestType:(uint32_t)requestType;

- (void)handleRequestType:(uint32_t)requestType tag:(uint32_t)tag object:(id)object;

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
