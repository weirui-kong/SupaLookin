#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  UIViewController+SPLKServer.m
//  SPLKServer
//
//  Created by Li Kai on 2019/4/22.
//  https://lookin.work
//

#import "UIViewController+SPLKServer.h"
#import "UIView+SPLKServer.h"
#import <objc/runtime.h>
#import "SPLKMultiplatformAdapter.h"

@implementation UIViewController (SPLKServer)

+ (nullable UIViewController *)splk_visibleViewController {
    
    UIViewController *rootViewController = [SPLKMultiplatformAdapter keyWindow].rootViewController;
    UIViewController *visibleViewController = [rootViewController splk_visibleViewControllerIfExist];
    return visibleViewController;
}

- (UIViewController *)splk_visibleViewControllerIfExist {
    
    if (self.presentedViewController) {
        return [self.presentedViewController splk_visibleViewControllerIfExist];
    }
    
    if ([self isKindOfClass:[UINavigationController class]]) {
        return [((UINavigationController *)self).visibleViewController splk_visibleViewControllerIfExist];
    }
    
    if ([self isKindOfClass:[UITabBarController class]]) {
        return [((UITabBarController *)self).selectedViewController splk_visibleViewControllerIfExist];
    }
    
    if (self.isViewLoaded && !self.view.hidden && self.view.alpha > 0.01) {
        return self;
    } else {
        return nil;
    }
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
