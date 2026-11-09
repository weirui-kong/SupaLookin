#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  UILabel+SPLKServer.m
//  SPLKServer
//
//  Created by Li Kai on 2019/2/26.
//  https://lookin.work
//

#import "UILabel+SPLKServer.h"

@implementation UILabel (SPLKServer)

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
