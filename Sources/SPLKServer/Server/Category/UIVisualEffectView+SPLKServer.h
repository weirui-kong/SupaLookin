#import <TargetConditionals.h>
#if TARGET_OS_IPHONE

//
//  UIVisualEffectView+SPLKServer.h
//  SPLKServer
//
//  Created by Li Kai on 2019/10/8.
//  https://lookin.work
//

#import <UIKit/UIKit.h>

@interface UIVisualEffectView (SPLKServer)

- (void)setSplk_blurEffectStyleNumber:(NSNumber *)splk_blurEffectStyleNumber;

- (NSNumber *)splk_blurEffectStyleNumber;

@end

#endif /* TARGET_OS_IPHONE */
