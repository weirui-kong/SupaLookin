#import <TargetConditionals.h>
#if TARGET_OS_IPHONE

//
//  SPLKConfigManager.h
//  SPLKServer
//
//  Created by likai.123 on 2023/1/10.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPLKConfigManager : NSObject

+ (NSArray<NSString *> *)collapsedClassList;

+ (NSDictionary<NSString *, UIColor *> *)colorAlias;

+ (BOOL)shouldCaptureScreenshotOfLayer:(CALayer *)layer;

@end

NS_ASSUME_NONNULL_END

#endif /* TARGET_OS_IPHONE */
