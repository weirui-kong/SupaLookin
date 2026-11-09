//
//  Image+SPLK.h
//  SPLKServer
//
//  Created by 李凯 on 2022/4/2.
//

#import "SPLKDefines.h"

#if TARGET_OS_IPHONE

#elif TARGET_OS_MAC

@interface NSImage (SPLKClient)

- (NSData *)splk_data;

@end

#endif
