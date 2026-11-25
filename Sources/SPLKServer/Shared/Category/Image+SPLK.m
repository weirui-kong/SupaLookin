//
//  Image+SPLK.m
//  SPLKServer
//
//  Created by 李凯 on 2022/4/2.
//

#import "Image+SPLK.h"

#if TARGET_OS_IPHONE

#elif TARGET_OS_MAC

@implementation NSImage (SPLKClient)

- (NSData *)splk_data {
    return [self TIFFRepresentation];
}

@end

#endif
