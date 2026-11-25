#import <TargetConditionals.h>
#if TARGET_OS_IPHONE

//
//  UIImage+SPLKServer.h
//  SPLKServer
//
//  Created by Li Kai on 2019/5/14.
//  https://lookin.work
//

#import <UIKit/UIKit.h>

@interface UIImage (SPLKServer)

/// 该方法的实现需要 Hook，因此若定义了 SPLK_SERVER_DISABLE_HOOK 宏，则属性会返回 nil
@property(nonatomic, copy) NSString *splk_imageSourceName;

- (NSData *)splk_data;

@end

#endif /* TARGET_OS_IPHONE */
