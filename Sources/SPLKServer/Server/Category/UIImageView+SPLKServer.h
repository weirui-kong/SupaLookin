#ifdef SHOULD_COMPILE_SPLK_SERVER 

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

#endif /* SHOULD_COMPILE_SPLK_SERVER */
