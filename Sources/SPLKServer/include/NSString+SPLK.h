//
//  NSString+SPLK.h
//  Lookin
//
//  Created by Li Kai on 2019/5/11.
//  https://lookin.work
//

#import "SPLKDefines.h"



#import <Foundation/Foundation.h>

@interface NSString (SPLK)

/**
 把 CGFloat 转成字符串，最多保留 3 位小数，转换后末尾的 0 会被删除
 如：1.2341 => @"1.234", 2.1002 => @"2.1", 3.000 => @"3"
 */
+ (NSString *)splk_stringFromDouble:(double)doubleValue decimal:(NSUInteger)decimal;

+ (NSString *)splk_stringFromRect:(CGRect)rect;

+ (NSString *)splk_stringFromInset:(SPLKInsets)insets;

+ (NSString *)splk_stringFromSize:(CGSize)size;

+ (NSString *)splk_stringFromPoint:(CGPoint)point;

+ (NSString *)splk_rgbaStringFromColor:(SPLKColor *)color;

- (NSString *)splk_safeInitWithUTF8String:(const char *)string;

/// 把 1.2.3 这种 String 版本号转换成数字，可用于大小比较，如 110205 代表 11.2.5 版本
- (NSInteger)splk_numbericOSVersion;

@end
