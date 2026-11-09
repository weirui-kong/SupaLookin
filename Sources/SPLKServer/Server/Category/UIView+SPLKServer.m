#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  UIView+SPLKServer.m
//  SPLKServer
//
//  Created by Li Kai on 2019/3/19.
//  https://lookin.work
//

#import "UIView+SPLKServer.h"
#import <objc/runtime.h>
#import "SPLKObject.h"
#import "SPLKAutoLayoutConstraint.h"
#import "SPLKServerDefines.h"
#import "SPLKMultiplatformAdapter.h"

@implementation UIView (SPLKServer)

- (UIViewController *)splk_findHostViewController {
    UIResponder *responder = [self nextResponder];
    if (!responder) {
        return nil;
    }
    if (![responder isKindOfClass:[UIViewController class]]) {
        return nil;
    }
    UIViewController *viewController = (UIViewController *)responder;
    if (viewController.view != self) {
        return nil;
    }
    return viewController;
}

- (UIView *)splk_subviewAtPoint:(CGPoint)point preferredClasses:(NSArray<Class> *)preferredClasses {
    BOOL isPreferredClassForSelf = [preferredClasses splk_any:^BOOL(Class obj) {
        return [self isKindOfClass:obj];
    }];
    if (isPreferredClassForSelf) {
        return self;
    }
    
    UIView *targetView = [self.subviews splk_lastFiltered:^BOOL(__kindof UIView *obj) {
        if (obj.hidden || obj.alpha <= 0.01) {
            return NO;
        }
        BOOL contains = CGRectContainsPoint(obj.frame, point);
        return contains;
    }];
    
    if (!targetView) {
        return self;
    }
    
    CGPoint newPoint = [targetView convertPoint:point fromView:self];
    targetView = [targetView splk_subviewAtPoint:newPoint preferredClasses:preferredClasses];
    return targetView;
}

- (CGSize)splk_bestSize {
    return [self sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
}

- (CGFloat)splk_bestWidth {
    return self.splk_bestSize.width;
}

- (CGFloat)splk_bestHeight {
    return self.splk_bestSize.height;
}

- (void)setSplk_isChildrenViewOfTabBar:(BOOL)splk_isChildrenViewOfTabBar {
    [self splk_bindBOOL:splk_isChildrenViewOfTabBar forKey:@"splk_isChildrenViewOfTabBar"];
}
- (BOOL)splk_isChildrenViewOfTabBar {
    return [self splk_getBindBOOLForKey:@"splk_isChildrenViewOfTabBar"];
}

- (void)setSplk_verticalContentHuggingPriority:(float)splk_verticalContentHuggingPriority {
    [self setContentHuggingPriority:splk_verticalContentHuggingPriority forAxis:UILayoutConstraintAxisVertical];
}
- (float)splk_verticalContentHuggingPriority {
    return [self contentHuggingPriorityForAxis:UILayoutConstraintAxisVertical];
}

- (void)setSplk_horizontalContentHuggingPriority:(float)splk_horizontalContentHuggingPriority {
    [self setContentHuggingPriority:splk_horizontalContentHuggingPriority forAxis:UILayoutConstraintAxisHorizontal];
}
- (float)splk_horizontalContentHuggingPriority {
    return [self contentHuggingPriorityForAxis:UILayoutConstraintAxisHorizontal];
}

- (void)setSplk_verticalContentCompressionResistancePriority:(float)splk_verticalContentCompressionResistancePriority {
    [self setContentCompressionResistancePriority:splk_verticalContentCompressionResistancePriority forAxis:UILayoutConstraintAxisVertical];
}
- (float)splk_verticalContentCompressionResistancePriority {
    return [self contentCompressionResistancePriorityForAxis:UILayoutConstraintAxisVertical];
}

- (void)setSplk_horizontalContentCompressionResistancePriority:(float)splk_horizontalContentCompressionResistancePriority {
    [self setContentCompressionResistancePriority:splk_horizontalContentCompressionResistancePriority forAxis:UILayoutConstraintAxisHorizontal];
}
- (float)splk_horizontalContentCompressionResistancePriority {
    return [self contentCompressionResistancePriorityForAxis:UILayoutConstraintAxisHorizontal];
}

+ (void)splk_rebuildGlobalInvolvedRawConstraints {
    [[SPLKMultiplatformAdapter allWindows] enumerateObjectsUsingBlock:^(__kindof UIWindow * _Nonnull window, NSUInteger idx, BOOL * _Nonnull stop) {
        [self splk_removeInvolvedRawConstraintsForViewsRootedByView:window];
    }];
    [[SPLKMultiplatformAdapter allWindows] enumerateObjectsUsingBlock:^(__kindof UIWindow * _Nonnull window, NSUInteger idx, BOOL * _Nonnull stop) {
        [self splk_addInvolvedRawConstraintsForViewsRootedByView:window];
    }];
}

+ (void)splk_addInvolvedRawConstraintsForViewsRootedByView:(UIView *)rootView {
    [rootView.constraints enumerateObjectsUsingBlock:^(__kindof NSLayoutConstraint * _Nonnull constraint, NSUInteger idx, BOOL * _Nonnull stop) {
        UIView *firstView = constraint.firstItem;
        if ([firstView isKindOfClass:[UIView class]] && ![firstView.splk_involvedRawConstraints containsObject:constraint]) {
            if (!firstView.splk_involvedRawConstraints) {
                firstView.splk_involvedRawConstraints = [NSMutableArray array];
            }
            [firstView.splk_involvedRawConstraints addObject:constraint];
        }
        
        UIView *secondView = constraint.secondItem;
        if ([secondView isKindOfClass:[UIView class]] && ![secondView.splk_involvedRawConstraints containsObject:constraint]) {
            if (!secondView.splk_involvedRawConstraints) {
                secondView.splk_involvedRawConstraints = [NSMutableArray array];
            }
            [secondView.splk_involvedRawConstraints addObject:constraint];
        }
    }];
    
    [rootView.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull subview, NSUInteger idx, BOOL * _Nonnull stop) {
        [self splk_addInvolvedRawConstraintsForViewsRootedByView:subview];
    }];
}

+ (void)splk_removeInvolvedRawConstraintsForViewsRootedByView:(UIView *)rootView {
    [rootView.splk_involvedRawConstraints removeAllObjects];
    [rootView.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull subview, NSUInteger idx, BOOL * _Nonnull stop) {
        [self splk_removeInvolvedRawConstraintsForViewsRootedByView:subview];
    }];
}

- (void)setSplk_involvedRawConstraints:(NSMutableArray<NSLayoutConstraint *> *)splk_involvedRawConstraints {
    [self splk_bindObject:splk_involvedRawConstraints forKey:@"splk_involvedRawConstraints"];
}

- (NSMutableArray<NSLayoutConstraint *> *)splk_involvedRawConstraints {
    return [self splk_getBindObjectForKey:@"splk_involvedRawConstraints"];
}

- (NSArray<SPLKAutoLayoutConstraint *> *)splk_constraints {
    /**
     - splk_involvedRawConstraints 保存了牵扯到了 self 的所有的 constraints（包括未生效的，但不包括 inactive 的，整个产品逻辑都是直接忽略 inactive 的 constraints）
     - 通过 constraintsAffectingLayoutForAxis 可以拿到会影响 self 布局的所有已生效的 constraints（这里称之为 effectiveConstraints）
     - 很多情况下，一条 constraint 会出现在 effectiveConstraints 里但不会出现在 splk_involvedRawConstraints 里，比如：
        · UIWindow 拥有 minX, minY, width, height 四个 effectiveConstraints，但 splk_involvedRawConstraints 为空，因为它的 constraints 属性为空（这一点不知道为啥，但 Xcode Inspector 和 Reveal 确实也不会显示这四个 constraints）
        · 如果设置了 View1 的 center 和 superview 的 center 保持一致，则 superview 的 width 和 height 也会出现在 effectiveConstraints 里，但不会出现在 splk_involvedRawConstraints 里（这点可以理解，毕竟这种场景下 superview 的 width 和 height 确实会影响到 View1）
     */
    NSMutableArray<NSLayoutConstraint *> *effectiveConstraints = [NSMutableArray array];
    [effectiveConstraints addObjectsFromArray:[self constraintsAffectingLayoutForAxis:UILayoutConstraintAxisHorizontal]];
    [effectiveConstraints addObjectsFromArray:[self constraintsAffectingLayoutForAxis:UILayoutConstraintAxisVertical]];
    
    NSArray<SPLKAutoLayoutConstraint *> *splkConstraints = [self.splk_involvedRawConstraints splk_map:^id(NSUInteger idx, __kindof NSLayoutConstraint *constraint) {
        BOOL isEffective = [effectiveConstraints containsObject:constraint];
        if ([constraint isActive]) {
            // trying to get firstItem or secondItem of an inactive constraint may cause dangling-pointer crash
            // https://github.com/QMUI/LookinServer/issues/86
            SPLKConstraintItemType firstItemType = [self _splk_constraintItemTypeForItem:constraint.firstItem];
            SPLKConstraintItemType secondItemType = [self _splk_constraintItemTypeForItem:constraint.secondItem];
            SPLKAutoLayoutConstraint *splkConstraint = [SPLKAutoLayoutConstraint instanceFromNSConstraint:constraint isEffective:isEffective firstItemType:firstItemType secondItemType:secondItemType];
            return splkConstraint;
        }
        return nil;
    }];
    return splkConstraints.count ? splkConstraints : nil;
}

- (SPLKConstraintItemType)_splk_constraintItemTypeForItem:(id)item {
    if (!item) {
        return SPLKConstraintItemTypeNil;
    }
    if (item == self) {
        return SPLKConstraintItemTypeSelf;
    }
    if (item == self.superview) {
        return SPLKConstraintItemTypeSuper;
    }
    
    // 在 runtime 时，这里会遇到的 UILayoutGuide 和 _UILayoutGuide 居然是 UIView 的子类，不知道是看错了还是有什么玄机，所以在判断是否是 UIView 之前要先判断这个
    if (@available(iOS 9.0, *)) {
        if ([item isKindOfClass:[UILayoutGuide class]]) {
            return SPLKConstraintItemTypeLayoutGuide;
        }
    }
    
    NSString *className = NSStringFromClass([item class]);
    if ([className hasSuffix:@"_UILayoutGuide"]) {
        return SPLKConstraintItemTypeLayoutGuide;
    }
    
    if ([item isKindOfClass:[UIView class]]) {
        return SPLKConstraintItemTypeView;
    }
    
    NSAssert(NO, @"");
    return SPLKConstraintItemTypeUnknown;
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
