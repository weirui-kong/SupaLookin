#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  SPLKHierarchyDisplayItemsMaker.m
//  SPLKServer
//
//  Created by Li Kai on 2019/2/19.
//  https://lookin.work
//

#import "SPLKHierarchyDisplayItemsMaker.h"
#import "SPLKDisplayItem.h"
#import "SPLKTraceManager.h"
#import "SPLKAttrGroupsMaker.h"
#import "SPLKEventHandlerMaker.h"
#import "SPLKServerDefines.h"
#import "UIColor+SPLKServer.h"
#import "SPLKConfigManager.h"
#import "SPLKCustomAttrGroupsMaker.h"
#import "SPLKCustomDisplayItemsMaker.h"
#import "SPLKCustomAttrSetterManager.h"
#import "SPLKMultiplatformAdapter.h"

@implementation SPLKHierarchyDisplayItemsMaker

+ (NSArray<SPLKDisplayItem *> *)itemsWithScreenshots:(BOOL)hasScreenshots attrList:(BOOL)hasAttrList lowImageQuality:(BOOL)lowQuality readCustomInfo:(BOOL)readCustomInfo saveCustomSetter:(BOOL)saveCustomSetter {
    
    [[SPLKTraceManager sharedInstance] reload];
    
    NSArray<UIWindow *> *windows = [SPLKMultiplatformAdapter allWindows];
    NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:windows.count];
    [windows enumerateObjectsUsingBlock:^(__kindof UIWindow * _Nonnull window, NSUInteger idx, BOOL * _Nonnull stop) {
        SPLKDisplayItem *item = [self _displayItemWithLayer:window.layer screenshots:hasScreenshots attrList:hasAttrList lowImageQuality:lowQuality readCustomInfo:readCustomInfo saveCustomSetter:saveCustomSetter];
        item.representedAsKeyWindow = window.isKeyWindow;
        if (item) {
            [resultArray addObject:item];
        }
    }];
    
    return [resultArray copy];
}

+ (SPLKDisplayItem *)_displayItemWithLayer:(CALayer *)layer screenshots:(BOOL)hasScreenshots attrList:(BOOL)hasAttrList lowImageQuality:(BOOL)lowQuality readCustomInfo:(BOOL)readCustomInfo saveCustomSetter:(BOOL)saveCustomSetter {
    if (!layer) {
        return nil;
    }
    
    SPLKDisplayItem *item = [SPLKDisplayItem new];
    CGRect layerFrame = layer.frame;
    UIView *hostView = layer.splk_hostView;
    if (hostView && hostView.superview) {
        layerFrame = [hostView.superview convertRect:layerFrame toView:nil];
    }
    if ([self validateFrame:layerFrame]) {
        item.frame = layer.frame;
    } else {
        NSLog(@"SPLKServer - The layer frame(%@) seems really weird. Lookin will ignore it to avoid potential render error in Lookin.", NSStringFromCGRect(layer.frame));
        item.frame = CGRectZero;
    }
    item.bounds = layer.bounds;
    if (hasScreenshots) {
        item.soloScreenshot = [layer splk_soloScreenshotWithLowQuality:lowQuality];
        item.groupScreenshot = [layer splk_groupScreenshotWithLowQuality:lowQuality];
        item.screenshotEncodeType = SPLKDisplayItemImageEncodeTypeNSData;
    }
    
    if (hasAttrList) {
        item.attributesGroupList = [SPLKAttrGroupsMaker attrGroupsForLayer:layer];
        SPLKCustomAttrGroupsMaker *maker = [[SPLKCustomAttrGroupsMaker alloc] initWithLayer:layer];
        [maker execute];
        item.customAttrGroupList = [maker getGroups];
        item.customDisplayTitle = [maker getCustomDisplayTitle];
        item.danceuiSource = [maker getDanceUISource];
    }
    
    item.isHidden = layer.isHidden;
    item.alpha = layer.opacity;
    item.layerObject = [SPLKObject instanceWithObject:layer];
    item.shouldCaptureImage = [SPLKConfigManager shouldCaptureScreenshotOfLayer:layer];
    
    if (layer.splk_hostView) {
        UIView *view = layer.splk_hostView;
        item.viewObject = [SPLKObject instanceWithObject:view];
        item.eventHandlers = [SPLKEventHandlerMaker makeForView:view];
        item.backgroundColor = view.backgroundColor;
        
        UIViewController* vc = [view splk_findHostViewController];
        if (vc) {
            item.hostViewControllerObject = [SPLKObject instanceWithObject:vc];
        }
    } else {
        item.backgroundColor = [UIColor splk_colorWithCGColor:layer.backgroundColor];
    }
    
    if (layer.sublayers.count) {
        NSArray<CALayer *> *sublayers = [layer.sublayers copy];
        NSMutableArray<SPLKDisplayItem *> *allSubitems = [NSMutableArray arrayWithCapacity:sublayers.count];
        [sublayers enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull sublayer, NSUInteger idx, BOOL * _Nonnull stop) {
            SPLKDisplayItem *sublayer_item = [self _displayItemWithLayer:sublayer screenshots:hasScreenshots attrList:hasAttrList lowImageQuality:lowQuality readCustomInfo:readCustomInfo saveCustomSetter:saveCustomSetter];
            if (sublayer_item) {
                [allSubitems addObject:sublayer_item];
            }
        }];
        item.subitems = [allSubitems copy];
    }
    if (readCustomInfo) {
        NSArray<SPLKDisplayItem *> *customSubitems = [[[SPLKCustomDisplayItemsMaker alloc] initWithLayer:layer saveAttrSetter:saveCustomSetter] make];
        if (customSubitems.count > 0) {
            if (item.subitems) {
                item.subitems = [item.subitems arrayByAddingObjectsFromArray:customSubitems];
            } else {
                item.subitems = customSubitems;
            }
        }        
    }
    
    return item;
}

+ (NSArray<SPLKDisplayItem *> *)subitemsOfLayer:(CALayer *)layer {
    if (!layer || layer.sublayers.count == 0) {
        return @[];
    }
    [[SPLKTraceManager sharedInstance] reload];
    
    NSMutableArray<SPLKDisplayItem *> *resultSubitems = [NSMutableArray array];

    NSArray<CALayer *> *sublayers = [layer.sublayers copy];
    [sublayers enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull sublayer, NSUInteger idx, BOOL * _Nonnull stop) {
        SPLKDisplayItem *sublayer_item = [self _displayItemWithLayer:sublayer screenshots:NO attrList:NO lowImageQuality:NO readCustomInfo:YES saveCustomSetter:YES];
        if (sublayer_item) {
            [resultSubitems addObject:sublayer_item];
        }
    }];

    NSArray<SPLKDisplayItem *> *customSubitems = [[[SPLKCustomDisplayItemsMaker alloc] initWithLayer:layer saveAttrSetter:YES] make];
    if (customSubitems.count > 0) {
        [resultSubitems addObjectsFromArray:customSubitems];
    }
    
    return resultSubitems;
}

+ (BOOL)validateFrame:(CGRect)frame {
    return !CGRectIsNull(frame) && !CGRectIsInfinite(frame) && ![self cgRectIsNaN:frame] && ![self cgRectIsInf:frame] && ![self cgRectIsUnreasonable:frame];
}

+ (BOOL)cgRectIsNaN:(CGRect)rect {
    return isnan(rect.origin.x) || isnan(rect.origin.y) || isnan(rect.size.width) || isnan(rect.size.height);
}

+ (BOOL)cgRectIsInf:(CGRect)rect {
    return isinf(rect.origin.x) || isinf(rect.origin.y) || isinf(rect.size.width) || isinf(rect.size.height);
}

+ (BOOL)cgRectIsUnreasonable:(CGRect)rect {
    return ABS(rect.origin.x) > 100000 || ABS(rect.origin.y) > 100000 || rect.size.width < 0 || rect.size.height < 0 || rect.size.width > 100000 || rect.size.height > 100000;
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
