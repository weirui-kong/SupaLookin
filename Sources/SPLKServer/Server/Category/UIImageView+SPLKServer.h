#import <TargetConditionals.h>
#if TARGET_OS_IPHONE

//
//  UIImageView+SPLKServer.h
//  SPLKServer
//
//  Created by Li Kai on 2019/9/18.
//  https://lookin.work
//

#import <UIKit/UIKit.h>

@interface UIImageView (SPLKServer)

- (NSString *)splk_imageSourceName;
- (NSNumber *)splk_imageViewOidIfHasImage;

@end

#endif /* TARGET_OS_IPHONE */
