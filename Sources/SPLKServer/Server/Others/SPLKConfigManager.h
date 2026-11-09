#ifdef SHOULD_COMPILE_SPLK_SERVER

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

#endif /* SHOULD_COMPILE_SPLK_SERVER */
