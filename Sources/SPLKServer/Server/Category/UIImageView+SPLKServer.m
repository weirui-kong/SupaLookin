#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  UIImageView+SPLKServer.m
//  SPLKServer
//
//  Created by Li Kai on 2019/9/18.
//  https://lookin.work
//

#import "UIImageView+SPLKServer.h"
#import "UIImage+SPLKServer.h"
#import "NSObject+SPLKServer.h"

@implementation UIImageView (SPLKServer)

- (NSString *)splk_imageSourceName {
    return self.image.splk_imageSourceName;
}

- (NSNumber *)splk_imageViewOidIfHasImage {
    if (!self.image) {
        return nil;
    }
    unsigned long oid = [self splk_registerOid];
    return @(oid);
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
