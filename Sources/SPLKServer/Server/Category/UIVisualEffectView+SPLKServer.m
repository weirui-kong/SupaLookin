#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  UIVisualEffectView+SPLKServer.m
//  SPLKServer
//
//  Created by Li Kai on 2019/10/8.
//  https://lookin.work
//

#import "UIVisualEffectView+SPLKServer.h"
#import "UIBlurEffect+SPLKServer.h"

@implementation UIVisualEffectView (SPLKServer)

- (void)setSplk_blurEffectStyleNumber:(NSNumber *)splk_blurEffectStyleNumber {
    UIBlurEffectStyle style = [splk_blurEffectStyleNumber integerValue];
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:style];
    self.effect = effect;
}

- (NSNumber *)splk_blurEffectStyleNumber {
    UIVisualEffect *effect = self.effect;
    if (![effect isKindOfClass:[UIBlurEffect class]]) {
        return nil;
    }
    UIBlurEffect *blurEffect = (UIBlurEffect *)effect;
    return blurEffect.splk_effectStyleNumber;
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
