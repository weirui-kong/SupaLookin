#import <TargetConditionals.h>
#if TARGET_OS_IPHONE

//
//  UITextField+SPLKServer.m
//  SPLKServer
//
//  Created by Li Kai on 2019/2/26.
//  https://lookin.work
//

#import "UITextField+SPLKServer.h"

@implementation UITextField (SPLKServer)

- (CGFloat)splk_fontSize {
    return self.font.pointSize;
}
- (void)setSplk_fontSize:(CGFloat)splk_fontSize {
    UIFont *font = [self.font fontWithSize:splk_fontSize];
    self.font = font;
}

- (NSString *)splk_fontName {
    return self.font.fontName;
}

@end

#endif /* TARGET_OS_IPHONE */
