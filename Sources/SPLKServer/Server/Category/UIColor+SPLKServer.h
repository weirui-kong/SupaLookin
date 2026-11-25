#import <TargetConditionals.h>
#if TARGET_OS_IPHONE

//
//  UIColor+SPLKServer.h
//  SPLKServer
//
//  Created by Li Kai on 2019/6/5.
//  https://lookin.work
//

#import <UIKit/UIKit.h>

@interface UIColor (SPLKServer)

- (NSArray<NSNumber *> *)splk_rgbaComponents;
+ (instancetype)splk_colorFromRGBAComponents:(NSArray<NSNumber *> *)components;

- (NSString *)splk_rgbaString;
- (NSString *)splk_hexString;

/// will check if the argument is a real CGColor
+ (UIColor *)splk_colorWithCGColor:(CGColorRef)cgColor;

@end

#endif /* TARGET_OS_IPHONE */
