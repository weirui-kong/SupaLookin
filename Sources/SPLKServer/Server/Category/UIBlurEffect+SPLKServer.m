#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  UIBlurEffect+SPLKServer.m
//  SPLKServer
//
//  Created by Li Kai on 2019/10/8.
//  https://lookin.work
//

#import "UIBlurEffect+SPLKServer.h"
#import "NSObject+SPLK.h"
#import <objc/runtime.h>

@implementation UIBlurEffect (SPLKServer)

#ifdef SPLK_SERVER_DISABLE_HOOK

- (void)setSplk_effectStyleNumber:(NSNumber *)splk_effectStyleNumber {
}

- (NSNumber *)splk_effectStyleNumber {
    return nil;
}

#else

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method oriMethod = class_getClassMethod([self class], @selector(effectWithStyle:));
        Method newMethod = class_getClassMethod([self class], @selector(splk_effectWithStyle:));
        method_exchangeImplementations(oriMethod, newMethod);
    });
}

+ (UIBlurEffect *)splk_effectWithStyle:(UIBlurEffectStyle)style {
    id effect = [self splk_effectWithStyle:style];
    if ([effect respondsToSelector:@selector(setSplk_effectStyleNumber:)]) {
        [effect setSplk_effectStyleNumber:@(style)];
    }
    return effect;
}

- (void)setSplk_effectStyleNumber:(NSNumber *)splk_effectStyleNumber {
    [self splk_bindObject:splk_effectStyleNumber forKey:@"splk_effectStyleNumber"];
}

- (NSNumber *)splk_effectStyleNumber {
    return [self splk_getBindObjectForKey:@"splk_effectStyleNumber"];
}

#endif /* SPLK_SERVER_DISABLE_HOOK */

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
