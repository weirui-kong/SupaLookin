#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  UIView+SPLKServer.h
//  SPLKServer
//
//  Created by Li Kai on 2019/3/19.
//  https://lookin.work
//

#import "SPLKDefines.h"
#import <UIKit/UIKit.h>

@interface UIView (SPLKServer)

/// 如果 myViewController.view = myView，则可以通过 myView 的 splk_findHostViewController 方法找到 myViewController
- (UIViewController *)splk_findHostViewController;

/// 是否是 UITabBar 的 childrenView，如果是的话，则截图时需要强制使用 renderInContext: 的方式而非 drawViewHierarchyInRect:afterScreenUpdates: 否则在 iOS 13 上获取到的图像是空的不知道为什么
@property(nonatomic, assign) BOOL splk_isChildrenViewOfTabBar;

/// point 是相对于 receiver 自身的坐标系
- (UIView *)splk_subviewAtPoint:(CGPoint)point preferredClasses:(NSArray<Class> *)preferredClasses;

- (CGFloat)splk_bestWidth;
- (CGFloat)splk_bestHeight;
- (CGSize)splk_bestSize;

@property(nonatomic, assign) float splk_horizontalContentHuggingPriority;
@property(nonatomic, assign) float splk_verticalContentHuggingPriority;

@property(nonatomic, assign) float splk_horizontalContentCompressionResistancePriority;
@property(nonatomic, assign) float splk_verticalContentCompressionResistancePriority;

/// 遍历全局的 view 并给他们设置 splk_involvedRawConstraints 属性
+ (void)splk_rebuildGlobalInvolvedRawConstraints;
/// 该属性保存了牵扯到当前 view 的所有 constraints，包括那些没有生效的
@property(nonatomic, strong) NSMutableArray<NSLayoutConstraint *> *splk_involvedRawConstraints;

- (NSArray<NSDictionary<NSString *, id> *> *)splk_constraints;

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
