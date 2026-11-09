#ifdef SHOULD_COMPILE_SPLK_SHARED 

//
//  NSString+SPLK.m
//  Lookin
//
//  Created by Li Kai on 2019/5/11.
//  https://lookin.work
//



#import "NSString+SPLK.h"

@implementation NSString (SPLK)

+ (NSString *)splk_stringFromDouble:(double)doubleValue decimal:(NSUInteger)decimal {
    NSString *formatString = [NSString stringWithFormat:@"%%.%@f", @(decimal)];
    NSString *string = [NSString stringWithFormat:formatString, doubleValue];
    for (int i = 0; i < decimal; i++) {
        if ([[string substringFromIndex:string.length - 1] isEqualToString:@"0"]) {
            string = [string substringToIndex:string.length - 1];
        }
    }
    if ([[string substringFromIndex:string.length - 1] isEqualToString:@"."]) {
        string = [string substringToIndex:string.length - 1];
    }
    return string;
}

+ (NSString *)splk_stringFromInset:(SPLKInsets)insets {
    return [NSString stringWithFormat:@"{%@, %@, %@, %@}",
            [NSString splk_stringFromDouble:insets.top decimal:2],
            [NSString splk_stringFromDouble:insets.left decimal:2],
            [NSString splk_stringFromDouble:insets.bottom decimal:2],
            [NSString splk_stringFromDouble:insets.right decimal:2]];
}

+ (NSString *)splk_stringFromSize:(CGSize)size {
    return [NSString stringWithFormat:@"{%@, %@}",
            [NSString splk_stringFromDouble:size.width decimal:2],
            [NSString splk_stringFromDouble:size.height decimal:2]];
}


+ (NSString *)splk_stringFromPoint:(CGPoint)point {
    return [NSString stringWithFormat:@"{%@, %@}",
            [NSString splk_stringFromDouble:point.x decimal:2],
            [NSString splk_stringFromDouble:point.y decimal:2]];
}

+ (NSString *)splk_stringFromRect:(CGRect)rect {
    return [NSString stringWithFormat:@"{%@, %@, %@, %@}",
            [NSString splk_stringFromDouble:rect.origin.x decimal:2],
            [NSString splk_stringFromDouble:rect.origin.y decimal:2],
            [NSString splk_stringFromDouble:rect.size.width decimal:2],
            [NSString splk_stringFromDouble:rect.size.height decimal:2]];
}

+ (NSString *)splk_rgbaStringFromColor:(SPLKColor *)color {
    if (!color) {
        return @"nil";
    }
    
#if TARGET_OS_IPHONE
    UIColor *rgbColor = color;
#elif TARGET_OS_MAC
    NSColor *rgbColor = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
#endif
    
    CGFloat r, g, b, a;
    [rgbColor getRed:&r green:&g blue:&b alpha:&a];
    
    NSString *colorDesc;
    if (a >= 1) {
        colorDesc = [NSString stringWithFormat:@"(%.0f, %.0f, %.0f)", r * 255, g * 255, b * 255];
    } else {
        colorDesc = [NSString stringWithFormat:@"(%.0f, %.0f, %.0f, %@)", r * 255, g * 255, b * 255, [NSString splk_stringFromDouble:a decimal:2]];
        
    }
    
    return colorDesc;
}

- (NSString *)splk_safeInitWithUTF8String:(const char *)string {
    if (NULL != string) {
        return [self initWithUTF8String:string];
    }
    return nil;
}

- (NSInteger)splk_numbericOSVersion {
    if (self.length == 0) {
        NSAssert(NO, @"");
        return 0;
    }
    NSArray *versionArr = [self componentsSeparatedByString:@"."];
    if (versionArr.count != 3) {
        NSAssert(NO, @"");
        return 0;
    }
    
    NSInteger numbericOSVersion = 0;
    NSInteger pos = 0;
    
    while ([versionArr count] > pos && pos < 3) {
        numbericOSVersion += ([[versionArr objectAtIndex:pos] integerValue] * pow(10, (4 - pos * 2)));
        pos++;
    }
    
    return numbericOSVersion;
}


@end

#endif /* SHOULD_COMPILE_SPLK_SHARED */
