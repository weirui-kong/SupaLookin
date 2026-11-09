#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  SPLKAttrModificationPatchHandler.m
//  SPLKServer
//
//  Created by Li Kai on 2019/6/12.
//  https://lookin.work
//

#import "SPLKAttrModificationPatchHandler.h"
#import "SPLKDisplayItemDetail.h"
#import "SPLKServerDefines.h"

@implementation SPLKAttrModificationPatchHandler

+ (void)handleLayerOids:(NSArray<NSNumber *> *)oids lowImageQuality:(BOOL)lowImageQuality block:(void (^)(SPLKDisplayItemDetail *detail, NSUInteger tasksTotalCount, NSError *error))block {
    if (!block) {
        NSAssert(NO, @"");
        return;
    }
    if (![oids isKindOfClass:[NSArray class]]) {
        block(nil, 1, SPLKErr_Inner);
        return;
    }
    
    [oids enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        unsigned long oid = [obj unsignedLongValue];
        SPLKDisplayItemDetail *detail = [SPLKDisplayItemDetail new];
        detail.displayItemOid = oid;
        
        CALayer *layer = (CALayer *)[NSObject splk_objectWithOid:oid];
        if (![layer isKindOfClass:[CALayer class]]) {
            block(nil, idx + 1, SPLKErr_ObjNotFound);
            *stop = YES;
            return;
        }
        
        if (idx == 0) {
            detail.soloScreenshot = [layer splk_soloScreenshotWithLowQuality:lowImageQuality];
            detail.groupScreenshot = [layer splk_groupScreenshotWithLowQuality:lowImageQuality];
        } else {
            detail.groupScreenshot = [layer splk_groupScreenshotWithLowQuality:lowImageQuality];
        }
        block(detail, oids.count, nil);
    }];
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
