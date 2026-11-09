#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  UIView+SPLKMobile.h
//  WeRead
//
//  Created by Li Kai on 2018/11/30.
//  Copyright © 2018 tencent. All rights reserved.
//

#import "SPLKDefines.h"
#import "TargetConditionals.h"
#import <UIKit/UIKit.h>

@interface CALayer (SPLKServer)

/// 如果 myView.layer == myLayer，则 myLayer.splk_hostView 会返回 myView
@property(nonatomic, readonly, weak) UIView *splk_hostView;

- (UIWindow *)splk_window;

- (CGRect)splk_frameInWindow:(UIWindow *)window;

- (UIImage *)splk_groupScreenshotWithLowQuality:(BOOL)lowQuality;
/// 当没有 sublayers 时，该方法返回 nil
- (UIImage *)splk_soloScreenshotWithLowQuality:(BOOL)lowQuality;

/// 获取和该对象有关的对象的 Class 层级树
- (NSArray<NSArray<NSString *> *> *)splk_relatedClassChainList;

- (NSArray<NSString *> *)splk_selfRelation;

@property(nonatomic, strong) UIColor *splk_backgroundColor;
@property(nonatomic, strong) UIColor *splk_borderColor;
@property(nonatomic, strong) UIColor *splk_shadowColor;
@property(nonatomic, assign) CGFloat splk_shadowOffsetWidth;
@property(nonatomic, assign) CGFloat splk_shadowOffsetHeight;

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
