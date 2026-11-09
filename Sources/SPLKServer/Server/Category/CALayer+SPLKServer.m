#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  UIView+SPLKMobile.m
//  WeRead
//
//  Created by Li Kai on 2018/11/30.
//  Copyright © 2018 tencent. All rights reserved.
//

#import "CALayer+SPLKServer.h"
#import "SPLKHierarchyDisplayItemsMaker.h"
#import "SPLKDisplayItem.h"
#import <objc/runtime.h>
#import "SPLKIvarTrace.h"
#import "SPLKServerDefines.h"
#import "UIColor+SPLKServer.h"
#import "SPLKMultiplatformAdapter.h"

@implementation CALayer (SPLKServer)

- (UIWindow *)splk_window {
    CALayer *layer = self;
    while (layer) {
        UIView *hostView = layer.splk_hostView;
        if (hostView.window) {
            return hostView.window;
        } else if ([hostView isKindOfClass:[UIWindow class]]) {
            return (UIWindow *)hostView;
        }
        layer = layer.superlayer;
    }
    return nil;
}

- (CGRect)splk_frameInWindow:(UIWindow *)window {
    UIWindow *selfWindow = [self splk_window];
    if (!selfWindow) {
        return CGRectZero;
    }
    
    CGRect rectInSelfWindow = [selfWindow.layer convertRect:self.frame fromLayer:self.superlayer];
    CGRect rectInWindow = [window convertRect:rectInSelfWindow fromWindow:selfWindow];
    return rectInWindow;
}

#pragma mark - Host View

- (UIView *)splk_hostView {
    if (self.delegate && [self.delegate isKindOfClass:UIView.class]) {
        UIView *view = (UIView *)self.delegate;
        if (view.layer == self) {
            return view;
        }
    }
    return nil;
}

#pragma mark - Screenshot

- (UIImage *)splk_groupScreenshotWithLowQuality:(BOOL)lowQuality {
    
    CGFloat screenScale = [SPLKMultiplatformAdapter mainScreenScale];
    CGFloat pixelWidth = self.frame.size.width * screenScale;
    CGFloat pixelHeight = self.frame.size.height * screenScale;
    if (pixelWidth <= 0 || pixelHeight <= 0) {
        return nil;
    }
    
    CGFloat renderScale = lowQuality ? 1 : 0;
    CGFloat maxLength = MAX(pixelWidth, pixelHeight);
    if (maxLength > SPLKNodeImageMaxLengthInPx) {
        // 确保最终绘制出的图片长和宽都不能超过 SPLKNodeImageMaxLengthInPx
        // 如果算出的 renderScale 大于 1 则取 1，因为似乎用 1 渲染的速度要比一个别的奇怪的带小数点的数字要更快
        renderScale = MIN(screenScale * SPLKNodeImageMaxLengthInPx / maxLength, 1);
    }
    
    CGSize contextSize = self.frame.size;
    if (contextSize.width <= 0 || contextSize.height <= 0 || contextSize.width > 20000 || contextSize.height > 20000) {
        NSLog(@"SPLKServer - Failed to capture screenshot. Invalid context size: %@ x %@", @(contextSize.width), @(contextSize.height));
        return nil;
    }
    UIGraphicsBeginImageContextWithOptions(contextSize, NO, renderScale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (self.splk_hostView && !self.splk_hostView.splk_isChildrenViewOfTabBar) {
        [self.splk_hostView drawViewHierarchyInRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height) afterScreenUpdates:YES];
    } else {
        [self renderInContext:context];
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIImage *)splk_soloScreenshotWithLowQuality:(BOOL)lowQuality {
    if (!self.sublayers.count) {
        return nil;
    }
    
    CGFloat screenScale = [SPLKMultiplatformAdapter mainScreenScale];
    CGFloat pixelWidth = self.frame.size.width * screenScale;
    CGFloat pixelHeight = self.frame.size.height * screenScale;
    if (pixelWidth <= 0 || pixelHeight <= 0) {
        return nil;
    }
    
    CGFloat renderScale = lowQuality ? 1 : 0;
    CGFloat maxLength = MAX(pixelWidth, pixelHeight);
    if (maxLength > SPLKNodeImageMaxLengthInPx) {
        // 确保最终绘制出的图片长和宽都不能超过 SPLKNodeImageMaxLengthInPx
        // 如果算出的 renderScale 大于 1 则取 1，因为似乎用 1 渲染的速度要比一个别的奇怪的带小数点的数字要更快
        renderScale = MIN(screenScale * SPLKNodeImageMaxLengthInPx / maxLength, 1);
    }
    
    if (self.sublayers.count) {
        NSArray<CALayer *> *sublayers = [self.sublayers copy];
        NSMutableArray<CALayer *> *visibleSublayers = [NSMutableArray arrayWithCapacity:sublayers.count];
        [sublayers enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull sublayer, NSUInteger idx, BOOL * _Nonnull stop) {
            if (!sublayer.hidden) {
                sublayer.hidden = YES;
                [visibleSublayers addObject:sublayer];
            }
        }];
        
        CGSize contextSize = self.frame.size;
        if (contextSize.width <= 0 || contextSize.height <= 0 || contextSize.width > 20000 || contextSize.height > 20000) {
            NSLog(@"SPLKServer - Failed to capture screenshot. Invalid context size: %@ x %@", @(contextSize.width), @(contextSize.height));
            return nil;
        }
        
        UIGraphicsBeginImageContextWithOptions(contextSize, NO, renderScale);
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (self.splk_hostView && !self.splk_hostView.splk_isChildrenViewOfTabBar) {
            [self.splk_hostView drawViewHierarchyInRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height) afterScreenUpdates:YES];
        } else {
            [self renderInContext:context];
        }
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        [visibleSublayers enumerateObjectsUsingBlock:^(CALayer * _Nonnull sublayer, NSUInteger idx, BOOL * _Nonnull stop) {
            sublayer.hidden = NO;
        }];
        
        return image;
    }
    return nil;
}

- (NSArray<NSArray<NSString *> *> *)splk_relatedClassChainList {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:2];
    if (self.splk_hostView) {
        [array addObject:[CALayer splk_getClassListOfObject:self.splk_hostView endingClass:@"UIView"]];
        UIViewController* vc = [self.splk_hostView splk_findHostViewController];
        if (vc) {
            [array addObject:[CALayer splk_getClassListOfObject:vc endingClass:@"UIViewController"]];
        }
    } else {
        [array addObject:[CALayer splk_getClassListOfObject:self endingClass:@"CALayer"]];
    }
    return array.copy;
}

+ (NSArray<NSString *> *)splk_getClassListOfObject:(id)object endingClass:(NSString *)endingClass {
    NSArray<NSString *> *completedList = [object splk_classChainList];
    NSUInteger endingIdx = [completedList indexOfObject:endingClass];
    if (endingIdx != NSNotFound) {
        completedList = [completedList subarrayWithRange:NSMakeRange(0, endingIdx + 1)];
    }
    return completedList;
}

- (NSArray<NSString *> *)splk_selfRelation {
    NSMutableArray *array = [NSMutableArray array];
    NSMutableArray<SPLKIvarTrace *> *ivarTraces = [NSMutableArray array];
    if (self.splk_hostView) {
        UIViewController* vc = [self.splk_hostView splk_findHostViewController];
        if (vc) {
            [array addObject:[NSString stringWithFormat:@"(%@ *).view", NSStringFromClass(vc.class)]];
            
            [ivarTraces addObjectsFromArray:vc.splk_ivarTraces];
        }
        [ivarTraces addObjectsFromArray:self.splk_hostView.splk_ivarTraces];
    } else {
        [ivarTraces addObjectsFromArray:self.splk_ivarTraces];
    }
    if (ivarTraces.count) {
        [array addObjectsFromArray:[ivarTraces splk_map:^id(NSUInteger idx, SPLKIvarTrace *value) {
            return [NSString stringWithFormat:@"(%@ *) -> %@", value.hostClassName, value.ivarName];
        }]];
    }
    return array.count ? array.copy : nil;
}

- (UIColor *)splk_backgroundColor {
    return [UIColor splk_colorWithCGColor:self.backgroundColor];
}
- (void)setSplk_backgroundColor:(UIColor *)splk_backgroundColor {
    self.backgroundColor = splk_backgroundColor.CGColor;
}

- (UIColor *)splk_borderColor {
    return [UIColor splk_colorWithCGColor:self.borderColor];
}
- (void)setSplk_borderColor:(UIColor *)splk_borderColor {
    self.borderColor = splk_borderColor.CGColor;
}

- (UIColor *)splk_shadowColor {
    return [UIColor splk_colorWithCGColor:self.shadowColor];
}
- (void)setSplk_shadowColor:(UIColor *)splk_shadowColor {
    self.shadowColor = splk_shadowColor.CGColor;
}

- (CGFloat)splk_shadowOffsetWidth {
    return self.shadowOffset.width;
}
- (void)setSplk_shadowOffsetWidth:(CGFloat)splk_shadowOffsetWidth {
    self.shadowOffset = CGSizeMake(splk_shadowOffsetWidth, self.shadowOffset.height);
}

- (CGFloat)splk_shadowOffsetHeight {
    return self.shadowOffset.height;
}
- (void)setSplk_shadowOffsetHeight:(CGFloat)splk_shadowOffsetHeight {
    self.shadowOffset = CGSizeMake(self.shadowOffset.width, splk_shadowOffsetHeight);
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
