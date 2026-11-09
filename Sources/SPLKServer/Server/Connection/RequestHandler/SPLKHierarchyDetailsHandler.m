#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  SPLKHierarchyDetailsHandler.m
//  SPLKServer
//
//  Created by Li Kai on 2019/6/20.
//  https://lookin.work
//

#import "SPLKHierarchyDetailsHandler.h"
#import "SPLKDisplayItemDetail.h"
#import "SPLKAttrGroupsMaker.h"
#import "SPLKStaticAsyncUpdateTask.h"
#import "SPLKConnectionManager.h"
#import "SPLKServerDefines.h"
#import "SPLKCustomAttrGroupsMaker.h"
#import "SPLKHierarchyDisplayItemsMaker.h"

@interface SPLKHierarchyDetailsHandler ()

@property(nonatomic, strong) NSMutableArray<SPLKStaticAsyncUpdateTasksPackage *> *taskPackages;
/// 标识哪些 oid 已经拉取过 attrGroups 了
@property(nonatomic, strong) NSMutableSet<NSNumber *> *attrGroupsSyncedOids;

@property(nonatomic, copy) SPLKHierarchyDetailsHandler_ProgressBlock progressBlock;
@property(nonatomic, copy) SPLKHierarchyDetailsHandler_FinishBlock finishBlock;

@end

@implementation SPLKHierarchyDetailsHandler

- (instancetype)init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleConnectionDidEnd:) name:SPLKConnectionDidEndNotificationName object:nil];
        
        self.attrGroupsSyncedOids = [NSMutableSet set];
    }
    return self;
}

- (void)startWithPackages:(NSArray<SPLKStaticAsyncUpdateTasksPackage *> *)packages block:(SPLKHierarchyDetailsHandler_ProgressBlock)progressBlock finishedBlock:(SPLKHierarchyDetailsHandler_FinishBlock)finishBlock {
    if (!progressBlock || !finishBlock) {
        NSAssert(NO, @"");
        return;
    }
    if (!packages.count) {
        finishBlock();
        return;
    }
    self.taskPackages = [packages mutableCopy];
    self.progressBlock = progressBlock;
    self.finishBlock = finishBlock;
    
    [UIView splk_rebuildGlobalInvolvedRawConstraints];
    
    [self _dequeueAndHandlePackage];
}

- (void)cancel {
    [self.taskPackages removeAllObjects];
}

- (void)_dequeueAndHandlePackage {
    dispatch_async(dispatch_get_main_queue(), ^{
        SPLKStaticAsyncUpdateTasksPackage *package = self.taskPackages.firstObject;
        if (!package) {
            self.finishBlock();
            return;
        }
        //        NSLog(@"SPLKServer - will handle tasks, count: %@", @(tasks.count));
        NSArray<SPLKDisplayItemDetail *> *details = [package.tasks splk_map:^id(NSUInteger idx, SPLKStaticAsyncUpdateTask *task) {
            SPLKDisplayItemDetail *itemDetail = [SPLKDisplayItemDetail new];
            itemDetail.displayItemOid = task.oid;
            
            id object = [NSObject splk_objectWithOid:task.oid];
            if (!object || ![object isKindOfClass:[CALayer class]]) {
                itemDetail.failureCode = -1;
                return itemDetail;
            }
            
            CALayer *layer = object;

            if (task.taskType == SPLKStaticAsyncUpdateTaskTypeSoloScreenshot) {
                UIImage *image = [layer splk_soloScreenshotWithLowQuality:NO];
                itemDetail.soloScreenshot = image;
            } else if (task.taskType == SPLKStaticAsyncUpdateTaskTypeGroupScreenshot) {
                UIImage *image = [layer splk_groupScreenshotWithLowQuality:NO];
                itemDetail.groupScreenshot = image;
            }
            
            BOOL shouldMakeAttr = [self queryIfShouldMakeAttrsFromTask:task];
            if (shouldMakeAttr) {
                itemDetail.attributesGroupList = [SPLKAttrGroupsMaker attrGroupsForLayer:layer];
                
                NSString *version = task.clientReadableVersion;
                if (version.length > 0 && [version splk_numbericOSVersion] >= 10004) {
                    SPLKCustomAttrGroupsMaker *maker = [[SPLKCustomAttrGroupsMaker alloc] initWithLayer:layer];
                    [maker execute];
                    itemDetail.customAttrGroupList = [maker getGroups];
                    itemDetail.customDisplayTitle = [maker getCustomDisplayTitle];
                    itemDetail.danceUISource = [maker getDanceUISource];
                }
                [self.attrGroupsSyncedOids addObject:@(task.oid)];
            }
            
            if (task.needBasisVisualInfo) {
                itemDetail.frameValue = [NSValue valueWithCGRect:layer.frame];
                itemDetail.boundsValue = [NSValue valueWithCGRect:layer.bounds];
                itemDetail.hiddenValue = [NSNumber numberWithBool:layer.isHidden];
                itemDetail.alphaValue = @(layer.opacity);
            }
            
            if (task.needSubitems) {
                itemDetail.subitems = [SPLKHierarchyDisplayItemsMaker subitemsOfLayer:layer];
            }
            
            return itemDetail;
        }];
        self.progressBlock(details);
        
        [self.taskPackages removeObjectAtIndex:0];
        [self _dequeueAndHandlePackage];
    });
}

- (BOOL)queryIfShouldMakeAttrsFromTask:(SPLKStaticAsyncUpdateTask *)task {
    switch (task.attrRequest) {
        case SPLKDetailUpdateTaskAttrRequest_Automatic: {
            BOOL alreadyMadeBefore = [self.attrGroupsSyncedOids containsObject:@(task.oid)];
            return !alreadyMadeBefore;
        }
        case SPLKDetailUpdateTaskAttrRequest_Need:
            return YES;
        case SPLKDetailUpdateTaskAttrRequest_NotNeed:
            return NO;
    }
    NSAssert(NO, @"");
    return YES;
}

- (void)_handleConnectionDidEnd:(id)obj {
    [self cancel];
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
