#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  SPLKInbuiltAttrModificationHandler.m
//  SPLKServer
//
//  Created by Li Kai on 2019/6/12.
//  https://lookin.work
//

#import "SPLKInbuiltAttrModificationHandler.h"
#import "UIColor+SPLKServer.h"
#import "SPLKAttributeModification.h"
#import "SPLKAttrGroupsMaker.h"
#import "SPLKDisplayItemDetail.h"
#import "SPLKStaticAsyncUpdateTask.h"
#import "SPLKServerDefines.h"
#import "SPLKCustomAttrGroupsMaker.h"

@implementation SPLKInbuiltAttrModificationHandler

+ (void)handleModification:(SPLKAttributeModification *)modification completion:(void (^)(SPLKDisplayItemDetail *data, NSError *error))completion {
    if (!completion) {
        NSAssert(NO, @"");
        return;
    }
    if (!modification || ![modification isKindOfClass:[SPLKAttributeModification class]]) {
        completion(nil, SPLKErr_Inner);
        return;
    }
    
    NSObject *receiver = [NSObject splk_objectWithOid:modification.targetOid];
    if (!receiver) {
        completion(nil, SPLKErr_ObjNotFound);
        return;
    }
    
    NSMethodSignature *setterSignature = [receiver methodSignatureForSelector:modification.setterSelector];
    NSInvocation *setterInvocation = [NSInvocation invocationWithMethodSignature:setterSignature];
    setterInvocation.target = receiver;
    setterInvocation.selector = modification.setterSelector;
    
    if (setterSignature.numberOfArguments != 3 || ![receiver respondsToSelector:modification.setterSelector]) {
        completion(nil, SPLKErr_Inner);
        return;
    }
    
    switch (modification.attrType) {
        case SPLKAttrTypeNone:
        case SPLKAttrTypeVoid: {
            completion(nil, SPLKErr_Inner);
            return;
        }
        case SPLKAttrTypeChar: {
            char expectedValue = [(NSNumber *)modification.value charValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeInt:
        case SPLKAttrTypeEnumInt: {
            int expectedValue = [(NSNumber *)modification.value intValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeShort: {
            short expectedValue = [(NSNumber *)modification.value shortValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeLong:
        case SPLKAttrTypeEnumLong: {
            long expectedValue = [(NSNumber *)modification.value longValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeLongLong: {
            long long expectedValue = [(NSNumber *)modification.value longLongValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeUnsignedChar: {
            unsigned char expectedValue = [(NSNumber *)modification.value unsignedCharValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeUnsignedInt: {
            unsigned int expectedValue = [(NSNumber *)modification.value unsignedIntValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeUnsignedShort: {
            unsigned short expectedValue = [(NSNumber *)modification.value unsignedShortValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeUnsignedLong: {
            unsigned long expectedValue = [(NSNumber *)modification.value unsignedLongValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeUnsignedLongLong: {
            unsigned long long expectedValue = [(NSNumber *)modification.value unsignedLongLongValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeFloat: {
            float expectedValue = [(NSNumber *)modification.value floatValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeDouble: {
            double expectedValue = [(NSNumber *)modification.value doubleValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeBOOL: {
            BOOL expectedValue = [(NSNumber *)modification.value boolValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeSel: {
            SEL expectedValue = NSSelectorFromString(modification.value);
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeClass: {
            Class expectedValue = NSClassFromString(modification.value);
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeCGPoint: {
            CGPoint expectedValue = [(NSValue *)modification.value CGPointValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeCGVector: {
            CGVector expectedValue = [(NSValue *)modification.value CGVectorValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeCGSize: {
            CGSize expectedValue = [(NSValue *)modification.value CGSizeValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeCGRect: {
            CGRect expectedValue = [(NSValue *)modification.value CGRectValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeCGAffineTransform: {
            CGAffineTransform expectedValue = [(NSValue *)modification.value CGAffineTransformValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeUIEdgeInsets: {
            UIEdgeInsets expectedValue = [(NSValue *)modification.value UIEdgeInsetsValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeUIOffset: {
            UIOffset expectedValue = [(NSValue *)modification.value UIOffsetValue];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case SPLKAttrTypeCustomObj:
        case SPLKAttrTypeNSString: {
            NSObject *expectedValue = modification.value;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            [setterInvocation retainArguments];
            break;
        }
        case SPLKAttrTypeUIColor: {
            NSArray<NSNumber *> *rgba = modification.value;
            UIColor *expectedValue = [UIColor splk_colorFromRGBAComponents:rgba];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            [setterInvocation retainArguments];
            break;
        }
        default: {
            completion(nil, SPLKErr_Inner);
            return;
        }
    }
    
    NSError *error = nil;
    @try {
        [setterInvocation invoke];
    } @catch (NSException *exception) {
        NSString *errorMsg = [NSString stringWithFormat:SPLKLocalized(@"<%@: %p>: an exception was raised when invoking %@. (%@)"), NSStringFromClass(receiver.class), receiver, NSStringFromSelector(modification.setterSelector), exception.reason];
        error = [NSError errorWithDomain:SPLKErrorDomain code:SPLKErrCode_Exception userInfo:@{NSLocalizedDescriptionKey:SPLKLocalized(@"The modification may failed."), NSLocalizedRecoverySuggestionErrorKey:errorMsg}];
    } @finally {
        
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CALayer *layer = nil;
        if ([receiver isKindOfClass:[CALayer class]]) {
            layer = (CALayer *)receiver;
        } else if ([receiver isKindOfClass:[UIView class]]) {
            layer = ((UIView *)receiver).layer;
        } else {
            completion(nil, SPLKErr_ObjNotFound);
            return;
        }
        // 比如试图更改 frame 时，这个改动很有可能触发用户业务的 relayout，因此这时 dispatch 一下以确保拿到的 attrGroups 数据是最新的
        SPLKDisplayItemDetail *detail = [SPLKDisplayItemDetail new];
        detail.displayItemOid = modification.targetOid;
        detail.attributesGroupList = [SPLKAttrGroupsMaker attrGroupsForLayer:layer];
        
        NSString *version = modification.clientReadableVersion;
        if (version.length > 0 && [version splk_numbericOSVersion] >= 10004) {
            SPLKCustomAttrGroupsMaker *maker = [[SPLKCustomAttrGroupsMaker alloc] initWithLayer:layer];
            [maker execute];
            detail.customAttrGroupList = [maker getGroups];
        }
        
        detail.frameValue = [NSValue valueWithCGRect:layer.frame];
        detail.boundsValue = [NSValue valueWithCGRect:layer.bounds];
        detail.hiddenValue = [NSNumber numberWithBool:layer.isHidden];
        detail.alphaValue = @(layer.opacity);
        completion(detail, error);
    });
}


+ (void)handlePatchWithTasks:(NSArray<SPLKStaticAsyncUpdateTask *> *)tasks block:(void (^)(SPLKDisplayItemDetail *data))block {
    if (!block) {
        NSAssert(NO, @"");
        return;
    }
    [tasks enumerateObjectsUsingBlock:^(SPLKStaticAsyncUpdateTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
        SPLKDisplayItemDetail *itemDetail = [SPLKDisplayItemDetail new];
        itemDetail.displayItemOid = task.oid;
        id object = [NSObject splk_objectWithOid:task.oid];
        if (!object || ![object isKindOfClass:[CALayer class]]) {
            block(itemDetail);
            return;
        }
        
        CALayer *layer = object;
        if (task.taskType == SPLKStaticAsyncUpdateTaskTypeSoloScreenshot) {
            UIImage *image = [layer splk_soloScreenshotWithLowQuality:NO];
            itemDetail.soloScreenshot = image;
        } else if (task.taskType == SPLKStaticAsyncUpdateTaskTypeGroupScreenshot) {
            UIImage *image = [layer splk_groupScreenshotWithLowQuality:NO];
            itemDetail.groupScreenshot = image;
        }
        block(itemDetail);
    }];
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
