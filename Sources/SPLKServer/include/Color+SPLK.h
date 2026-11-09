#ifdef SHOULD_COMPILE_SPLK_SHARED 

//
//  Color+SPLK.h
//  SPLKServer
//
//  Created by 李凯 on 2022/4/2.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE

#elif TARGET_OS_MAC

@interface NSColor (SPLK)

+ (instancetype)splk_colorFromRGBAComponents:(NSArray<NSNumber *> *)components;

- (NSArray<NSNumber *> *)splk_rgbaComponents;

@end

#endif


#endif /* SHOULD_COMPILE_SPLK_SHARED */
