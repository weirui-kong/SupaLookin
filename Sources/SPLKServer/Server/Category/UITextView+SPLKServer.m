#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  UITextView+SPLKServer.m
//  SPLKServer
//
//  Created by Li Kai on 2019/2/26.
//  https://lookin.work
//

#import "UITextView+SPLKServer.h"

@implementation UITextView (SPLKServer)

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

#endif /* SHOULD_COMPILE_SPLK_SERVER */
