#import <TargetConditionals.h>
#if TARGET_OS_IPHONE

//
//  UIViewController+SPLKServer.h
//  SPLKServer
//
//  Created by Li Kai on 2019/4/22.
//  https://lookin.work
//

#import <UIKit/UIKit.h>

@interface UIViewController (SPLKServer)

+ (UIViewController *)splk_visibleViewController;

@end

#endif /* TARGET_OS_IPHONE */
