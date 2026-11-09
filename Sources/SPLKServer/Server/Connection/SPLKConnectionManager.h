#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  Lookin.h
//  Lookin
//
//  Created by Li Kai on 2018/8/5.
//  https://lookin.work
//

#import <UIKit/UIKit.h>

extern NSString *const SPLKConnectionDidEndNotificationName;

@class SPLKConnectionResponseAttachment;

@interface SPLKConnectionManager : NSObject

+ (instancetype)sharedInstance;

@property(nonatomic, assign) BOOL applicationIsActive;

- (void)respond:(SPLKConnectionResponseAttachment *)data requestType:(uint32_t)requestType tag:(uint32_t)tag;

- (void)pushData:(NSObject *)data type:(uint32_t)type;

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
