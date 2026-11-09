#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  SPLKTraceManager.m
//  SPLKServer
//
//  Created by Li Kai on 2019/5/5.
//  https://lookin.work
//

#import "SPLKTraceManager.h"
#import <objc/runtime.h>
#import "SPLKIvarTrace.h"
#import "SPLKServerDefines.h"
#import "SPLKWeakContainer.h"
#import "SPLKMultiplatformAdapter.h"

@import SPLKServerSwift;

@interface SPLKTraceManager ()

@property(nonatomic, strong) NSMutableArray<SPLKWeakContainer *> *searchTargets;

@end

@implementation SPLKTraceManager

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static SPLKTraceManager *instance = nil;
    dispatch_once(&onceToken,^{
        instance = [[super allocWithZone:NULL] init];
    });
    return instance;
}

+ (id)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (void)addSearchTarger:(id)target {
    if (!target) {
        return;
    }
    if (!self.searchTargets) {
        self.searchTargets = [NSMutableArray array];
    }
    SPLKWeakContainer *container = [SPLKWeakContainer containerWithObject:target];
    [self.searchTargets addObject:container];
}

- (void)reload {
    // 把旧的先都清理掉
    [NSObject splk_clearAllObjectsTraces];
    
    [self.searchTargets enumerateObjectsUsingBlock:^(SPLKWeakContainer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (!obj.object) {
            return;
        }
        [self _markIVarsInAllClassLevelsOfObject:obj.object];
    }];
    
    [[SPLKMultiplatformAdapter allWindows] enumerateObjectsUsingBlock:^(__kindof UIWindow * _Nonnull window, NSUInteger idx, BOOL * _Nonnull stop) {
        [self _addTraceForLayersRootedByLayer:window.layer];
    }];
}

- (void)_addTraceForLayersRootedByLayer:(CALayer *)layer {
    UIView *view = layer.splk_hostView;
    
    if ([view.superview splk_isChildrenViewOfTabBar]) {
        view.splk_isChildrenViewOfTabBar = YES;
    } else if ([view isKindOfClass:[UITabBar class]]) {
        view.splk_isChildrenViewOfTabBar = YES;
    }
    
    if (view) {
        [self _markIVarsInAllClassLevelsOfObject:view];
        UIViewController* vc = [view splk_findHostViewController];
        if (vc) {
            [self _markIVarsInAllClassLevelsOfObject:vc];
        }
        
        [self _buildSpecialTraceForView:view];
    } else {
        [self _markIVarsInAllClassLevelsOfObject:layer];
    }
    
    [[layer.sublayers copy] enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull sublayer, NSUInteger idx, BOOL * _Nonnull stop) {
        [self _addTraceForLayersRootedByLayer:sublayer];
    }];
}

- (void)_buildSpecialTraceForView:(UIView *)view {
    UIViewController* vc = [view splk_findHostViewController];
    if (vc) {
        view.splk_specialTrace = [NSString stringWithFormat:@"%@.view", NSStringFromClass(vc.class)];
        
    } else if ([view isKindOfClass:[UIWindow class]]) {
        CGFloat currentWindowLevel = ((UIWindow *)view).windowLevel;
        
        if (((UIWindow *)view).isKeyWindow) {
            view.splk_specialTrace = [NSString stringWithFormat:@"KeyWindow ( Level: %@ )", @(currentWindowLevel)];
        } else {
            view.splk_specialTrace = [NSString stringWithFormat:@"WindowLevel: %@", @(currentWindowLevel)];
        }
    } else if ([view isKindOfClass:[UITableViewCell class]]) {
        ((UITableViewCell *)view).backgroundView.splk_specialTrace = @"cell.backgroundView";
        ((UITableViewCell *)view).accessoryView.splk_specialTrace = @"cell.accessoryView";
    
    } else if ([view isKindOfClass:[UITableView class]]) {
        UITableView *tableView = (UITableView *)view;
        
        NSMutableArray<NSNumber *> *relatedSectionIdx = [NSMutableArray array];
        [[tableView visibleCells] enumerateObjectsUsingBlock:^(__kindof UITableViewCell * _Nonnull cell, NSUInteger idx, BOOL * _Nonnull stop) {
            NSIndexPath *indexPath = [tableView indexPathForCell:cell];
            cell.splk_specialTrace = [NSString stringWithFormat:@"{ sec:%@, row:%@ }", @(indexPath.section), @(indexPath.row)];
            
            if (![relatedSectionIdx containsObject:@(indexPath.section)]) {
                [relatedSectionIdx addObject:@(indexPath.section)];
            }
        }];
        
        [relatedSectionIdx enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSUInteger secIdx = [obj unsignedIntegerValue];
            UIView *secHeaderView = [tableView headerViewForSection:secIdx];
            secHeaderView.splk_specialTrace = [NSString stringWithFormat:@"sectionHeader { sec: %@ }", @(secIdx)];
            
            UIView *secFooterView = [tableView footerViewForSection:secIdx];
            secFooterView.splk_specialTrace = [NSString stringWithFormat:@"sectionFooter { sec: %@ }", @(secIdx)];
        }];
        
    } else if ([view isKindOfClass:[UICollectionView class]]) {
        UICollectionView *collectionView = (UICollectionView *)view;
        collectionView.backgroundView.splk_specialTrace = @"collectionView.backgroundView";
        
        if (@available(iOS 9.0, *)) {
            [[collectionView indexPathsForVisibleSupplementaryElementsOfKind:UICollectionElementKindSectionHeader] enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull indexPath, NSUInteger idx, BOOL * _Nonnull stop) {
                UIView *headerView = [collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader atIndexPath:indexPath];
                headerView.splk_specialTrace = [NSString stringWithFormat:@"sectionHeader { sec:%@ }", @(indexPath.section)];
            }];
            [[collectionView indexPathsForVisibleSupplementaryElementsOfKind:UICollectionElementKindSectionFooter] enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull indexPath, NSUInteger idx, BOOL * _Nonnull stop) {
                UIView *footerView = [collectionView supplementaryViewForElementKind:UICollectionElementKindSectionFooter atIndexPath:indexPath];
                footerView.splk_specialTrace = [NSString stringWithFormat:@"sectionFooter { sec:%@ }", @(indexPath.section)];
            }];
        }
        
        [[collectionView visibleCells] enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell * _Nonnull cell, NSUInteger idx, BOOL * _Nonnull stop) {
            NSIndexPath *indexPath = [collectionView indexPathForCell:cell];
            cell.splk_specialTrace = [NSString stringWithFormat:@"{ item:%@, sec:%@ }", @(indexPath.item), @(indexPath.section)];
        }];
        
    } else if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *headerFooterView = (UITableViewHeaderFooterView *)view;
        headerFooterView.textLabel.splk_specialTrace = @"sectionHeaderFooter.textLabel";
        headerFooterView.detailTextLabel.splk_specialTrace = @"sectionHeaderFooter.detailTextLabel";
    }
}

- (void)_markIVarsInAllClassLevelsOfObject:(NSObject *)object {
    [self _markIVarsOfObject:object class:object.class];
    [SPLKSwiftTraceManager swiftMarkIVarsOfObject:object];
}

- (void)_markIVarsOfObject:(NSObject *)hostObject class:(Class)targetClass {
    if (!targetClass) {
        return;
    }

    NSArray<NSString *> *prefixesToTerminateRecursion = @[@"NSObject", @"UIResponder", @"UIButton", @"UIButtonLabel"];
    BOOL hasPrefix = [prefixesToTerminateRecursion splk_any:^BOOL(NSString *prefix) {
        return [NSStringFromClass(targetClass) hasPrefix:prefix];
    }];
    if (hasPrefix) {
        return;
    }
    
    unsigned int outCount = 0;
    Ivar *ivars = class_copyIvarList(targetClass, &outCount);
    for (unsigned int i = 0; i < outCount; i ++) {
        Ivar ivar = ivars[i];
        NSString *ivarType = [[NSString alloc] splk_safeInitWithUTF8String:ivar_getTypeEncoding(ivar)];
        if (![ivarType hasPrefix:@"@"] || ivarType.length <= 3) {
            continue;
        }
        NSString *ivarClassName = [ivarType substringWithRange:NSMakeRange(2, ivarType.length - 3)];
        Class ivarClass = NSClassFromString(ivarClassName);
        if (![ivarClass isSubclassOfClass:[UIView class]]
            && ![ivarClass isSubclassOfClass:[CALayer class]]
            && ![ivarClass isSubclassOfClass:[UIViewController class]]
            && ![ivarClass isSubclassOfClass:[UIGestureRecognizer class]]) {
            continue;
        }
        const char * ivarNameChar = ivar_getName(ivar);
        if (!ivarNameChar) {
            continue;
        }
        // 这个 ivarObject 可能的类型：UIView, CALayer, UIViewController, UIGestureRecognizer
        NSObject *ivarObject = object_getIvar(hostObject, ivar);
        if (!ivarObject || ![ivarObject isKindOfClass:[NSObject class]]) {
            continue;
        }

        SPLKIvarTrace *ivarTrace = [SPLKIvarTrace new];
        ivarTrace.hostObject = hostObject;
        ivarTrace.hostClassName = [self makeDisplayClassNameWithSuper:targetClass childClass:hostObject.class];
        ivarTrace.ivarName = [[NSString alloc] splk_safeInitWithUTF8String:ivarNameChar];
        
        if (hostObject == ivarObject) {
            ivarTrace.relation = SPLKIvarTraceRelationValue_Self;
        } else if ([hostObject isKindOfClass:[UIView class]]) {
            CALayer *ivarLayer = nil;
            if ([ivarObject isKindOfClass:[CALayer class]]) {
                ivarLayer = (CALayer *)ivarObject;
            } else if ([ivarObject isKindOfClass:[UIView class]]) {
                ivarLayer = ((UIView *)ivarObject).layer;
            }
            if (ivarLayer && (ivarLayer.superlayer == ((UIView *)hostObject).layer)) {
                ivarTrace.relation = @"superview";
            }
        }

        if ([SPLKInvalidIvarTraces() containsObject:ivarTrace]) {
            continue;
        }
        
        if (![ivarObject respondsToSelector:@selector(splk_ivarTraces)] || ![ivarObject respondsToSelector:@selector(setSplk_ivarTraces:)]) {
            continue;
        }
        if (!ivarObject.splk_ivarTraces) {
            ivarObject.splk_ivarTraces = [NSArray array];
        }
        if (![ivarObject.splk_ivarTraces containsObject:ivarTrace]) {
            ivarObject.splk_ivarTraces = [ivarObject.splk_ivarTraces arrayByAddingObject:ivarTrace];
        }
    }
    free(ivars);
    
    Class superClass = [targetClass superclass];
    [self _markIVarsOfObject:hostObject class:superClass];
}

// 比如 superClass 可能是 UIView，而 childClass 可能是 UIButton
- (NSString *)makeDisplayClassNameWithSuper:(Class)superClass childClass:(Class)childClass {
    NSString *superName = NSStringFromClass(superClass);
    if (!childClass) {
        return superName;
    }
    NSString *childName = NSStringFromClass(childClass);
    if ([childName isEqualToString:superName]) {
        return superName;
    }
    return [NSString stringWithFormat:@"%@ : %@", childName, superName];
}

static NSSet<SPLKIvarTrace *> *SPLKInvalidIvarTraces(void) {
    static NSSet *list;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableSet *set = [NSMutableSet set];
        
        [set addObject:({
            SPLKIvarTrace *trace = [SPLKIvarTrace new];
            trace.hostClassName = @"UIView";
            trace.ivarName = @"_window";
            trace;
        })];
        [set addObject:({
            SPLKIvarTrace *trace = [SPLKIvarTrace new];
            trace.hostClassName = @"UIViewController";
            trace.ivarName = @"_view";
            trace;
        })];
        [set addObject:({
            SPLKIvarTrace *trace = [SPLKIvarTrace new];
            trace.hostClassName = @"UIView";
            trace.ivarName = @"_viewDelegate";
            trace;
        })];
        [set addObject:({
            SPLKIvarTrace *trace = [SPLKIvarTrace new];
            trace.hostClassName = @"UIViewController";
            trace.ivarName = @"_parentViewController";
            trace;
        })];
        list = set.copy;
    });
    return list;
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
