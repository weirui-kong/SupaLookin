#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
//
//  SPLKMultiplatformAdapter.h
//  
//
//  Created by nixjiang on 2024/3/12.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPLKMultiplatformAdapter : NSObject

+ (UIWindow *)keyWindow;

+ (NSArray<UIWindow *> *)allWindows;

+ (CGRect)mainScreenBounds;

+ (CGFloat)mainScreenScale;

+ (BOOL)isiPad;

@end

NS_ASSUME_NONNULL_END

#endif /* TARGET_OS_IPHONE */
