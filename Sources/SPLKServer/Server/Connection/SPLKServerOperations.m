#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  SPLKServerOperations.m
//  SPLKServer
//
//  Created by Li Kai on 2019/1/15.
//  https://lookin.work
//

#import "SPLKServerOperations.h"
#import "NSObject+SPLKServer.h"
#import "UIImage+SPLKServer.h"
#import "SPLKAttributeModification.h"
#import "SPLKDisplayItemDetail.h"
#import "SPLKHierarchyInfo.h"
#import "SPLKServerDefines.h"
#import <objc/runtime.h>
#import "SPLKObject.h"
#import "SPLKAppInfo.h"
#import "SPLKAttrGroupsMaker.h"
#import "SPLKInbuiltAttrModificationHandler.h"
#import "SPLKCustomAttrModificationHandler.h"
#import "SPLKHierarchyDetailsHandler.h"
#import "SPLKStaticAsyncUpdateTask.h"

@implementation SPLKServerOperations

+ (SPLKAppInfo *)appInfoWithImages:(BOOL)needImages localIdentifiers:(NSArray<NSNumber *> *)localIdentifiers {
    return [SPLKAppInfo currentInfoWithScreenshot:needImages icon:needImages localIdentifiers:localIdentifiers];
}

+ (SPLKHierarchyInfo *)hierarchyWithClientVersion:(NSString *)clientVersion {
    return [SPLKHierarchyInfo staticInfoWithSPLKVersion:clientVersion];
}

+ (id)fetchDetailsWithPackages:(NSArray<SPLKStaticAsyncUpdateTasksPackage *> *)packages progress:(void (^)(NSArray<SPLKDisplayItemDetail *> *))progress finished:(void (^)(void))finished {
    SPLKHierarchyDetailsHandler *handler = [SPLKHierarchyDetailsHandler new];
    [handler startWithPackages:packages block:progress finishedBlock:finished];
    return handler;
}

+ (void)cancelDetailsFetching:(id)fetching {
    if ([fetching isKindOfClass:[SPLKHierarchyDetailsHandler class]]) {
        [(SPLKHierarchyDetailsHandler *)fetching cancel];
    }
}

+ (void)modifyAttribute:(SPLKAttributeModification *)modification reply:(void (^)(SPLKDisplayItemDetail *, NSError *))reply {
    [SPLKInbuiltAttrModificationHandler handleModification:modification completion:reply];
}

+ (void)fetchModificationPatchWithTasks:(NSArray<SPLKStaticAsyncUpdateTask *> *)tasks progress:(void (^)(SPLKDisplayItemDetail *))progress {
    [SPLKInbuiltAttrModificationHandler handlePatchWithTasks:tasks block:progress];
}

+ (BOOL)modifyCustomAttribute:(SPLKCustomAttrModification *)modification {
    return [SPLKCustomAttrModificationHandler handleModification:modification];
}

+ (SPLKObject *)objectWithOid:(unsigned long)oid {
    NSObject *object = [NSObject splk_objectWithOid:oid];
    return [SPLKObject instanceWithObject:object];
}

+ (id)liveObjectForOid:(unsigned long)oid {
    return [NSObject splk_objectWithOid:oid];
}

+ (void)attributeGroupsForLayerOid:(unsigned long)oid reply:(void (^)(NSArray<SPLKAttributesGroup *> *, NSError *))reply {
    CALayer *layer = (CALayer *)[NSObject splk_objectWithOid:oid];
    if (![layer isKindOfClass:[CALayer class]]) {
        reply(nil, SPLKErr_ObjNotFound);
        return;
    }
    reply([SPLKAttrGroupsMaker attrGroupsForLayer:layer], nil);
}

+ (void)selectorNamesForClassName:(NSString *)className hasArg:(BOOL)hasArg reply:(void (^)(NSArray<NSString *> *, NSError *))reply {
    Class targetClass = NSClassFromString(className);
    if (!targetClass) {
        // v1 formatted its whole request parameters into this message.
        NSDictionary *params = @{@"className": className, @"hasArg": @(hasArg)};
        NSString *errorMsg = [NSString stringWithFormat:SPLKLocalized(@"Didn't find the class named \"%@\". Please input another class and try again."), params];
        reply(nil, SPLKErrorMake(errorMsg, @""));
        return;
    }
    reply([self _methodNameListForClass:targetClass hasArg:hasArg], nil);
}

+ (void)invokeMethodOnOid:(unsigned long)oid text:(NSString *)text reply:(void (^)(NSDictionary<NSString *, id> *, NSError *))reply {
    if (!text.length) {
        reply(nil, SPLKErr_Inner);
        return;
    }
    NSObject *targerObj = [NSObject splk_objectWithOid:oid];
    if (!targerObj) {
        reply(nil, SPLKErr_ObjNotFound);
        return;
    }
    
    SEL targetSelector = NSSelectorFromString(text);
    if (targetSelector && [targerObj respondsToSelector:targetSelector]) {
        NSString *resultDescription;
        NSObject *resultObject;
        NSError *error;
        [self _handleInvokeWithObject:targerObj selector:targetSelector resultDescription:&resultDescription resultObject:&resultObject error:&error];
        if (error) {
            reply(nil, error);
            return;
        }
        NSMutableDictionary *responseData = [NSMutableDictionary dictionaryWithCapacity:2];
        if (resultDescription) {
            responseData[@"description"] = resultDescription;
        }
        if (resultObject) {
            responseData[@"object"] = resultObject;
        }
        reply(responseData, nil);
    } else {
        NSString *errMsg = [NSString stringWithFormat:SPLKLocalized(@"%@ doesn't have an instance method called \"%@\"."), NSStringFromClass(targerObj.class), text];
        reply(nil, SPLKErrorMake(errMsg, @""));
    }
}

+ (void)imageDataForImageViewOid:(unsigned long)oid reply:(void (^)(NSData *, NSError *))reply {
    UIImageView *imageView = (UIImageView *)[NSObject splk_objectWithOid:oid];
    if (!imageView) {
        reply(nil, SPLKErr_ObjNotFound);
        return;
    }
    if (![imageView isKindOfClass:[UIImageView class]]) {
        reply(nil, SPLKErr_Inner);
        return;
    }
    UIImage *image = imageView.image;
    reply([image splk_data], nil);
}

+ (void)setGestureRecognizerOid:(unsigned long)oid enabled:(BOOL)enabled reply:(void (^)(NSNumber *, NSError *))reply {
    UIGestureRecognizer *recognizer = (UIGestureRecognizer *)[NSObject splk_objectWithOid:oid];
    if (!recognizer) {
        reply(nil, SPLKErr_ObjNotFound);
        return;
    }
    if (![recognizer isKindOfClass:[UIGestureRecognizer class]]) {
        reply(nil, SPLKErr_Inner);
        return;
    }
    recognizer.enabled = enabled;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // dispatch 以确保拿到的 enabled 是比较新的
        reply(@(recognizer.enabled), nil);
    });
}

+ (NSArray<NSString *> *)_methodNameListForClass:(Class)aClass hasArg:(BOOL)hasArg {
    NSSet<NSString *> *prefixesToVoid = [NSSet setWithObjects:@"_", @"CA_", @"cpl", @"mf_", @"vs_", @"pep_", @"isNS", @"avkit_", @"PG_", @"px_", @"pl_", @"nsli_", @"pu_", @"pxg_", nil];
    NSMutableArray<NSString *> *array = [NSMutableArray array];
    
    Class currentClass = aClass;
    while (currentClass) {
        NSString *className = NSStringFromClass(currentClass);
        BOOL isSystemClass = ([className hasPrefix:@"UI"] || [className hasPrefix:@"CA"] || [className hasPrefix:@"NS"]);
        
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(currentClass, &methodCount);
        for (unsigned int i = 0; i < methodCount; i++) {
            NSString *selName = NSStringFromSelector(method_getName(methods[i]));
            
            if (!hasArg && [selName containsString:@":"]) {
                continue;
            }
            
            if (isSystemClass) {
                BOOL invalid = [prefixesToVoid splk_any:^BOOL(NSString *prefix) {
                    return [selName hasPrefix:prefix];
                }];
                if (invalid) {
                    continue;
                }
            }
            if (selName.length && ![array containsObject:selName]) {
                [array addObject:selName];
            }
        }
        if (methods) free(methods);
        currentClass = [currentClass superclass];
    }

    return [array splk_sortedArrayByStringLength];
}

+ (void)_handleInvokeWithObject:(NSObject *)obj selector:(SEL)selector resultDescription:(NSString **)description resultObject:(SPLKObject **)resultObject error:(NSError **)error {
    NSMethodSignature *signature = [obj methodSignatureForSelector:selector];
    if (signature.numberOfArguments > 2) {
        *error = SPLKErrorMake(SPLKLocalized(@"Lookin doesn't support invoking methods with arguments yet."), @"");
        return;
    }
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:obj];
    [invocation setSelector:selector];
    [invocation invoke];

    const char *returnType = [signature methodReturnType];
    
    
    if (strcmp(returnType, @encode(void)) == 0) {
        //void, do nothing
        *description = SPLKStringFlag_VoidReturn;
        
    } else if (strcmp(returnType, @encode(char)) == 0) {
        char charValue;
        [invocation getReturnValue:&charValue];
        *description = [NSString stringWithFormat:@"%@", @(charValue)];
        
    } else if (strcmp(returnType, @encode(int)) == 0) {
        int intValue;
        [invocation getReturnValue:&intValue];
        if (intValue == INT_MAX) {
            *description = @"INT_MAX";
        } else if (intValue == INT_MIN) {
            *description = @"INT_MIN";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(intValue)];
        }
        
    } else if (strcmp(returnType, @encode(short)) == 0) {
        short shortValue;
        [invocation getReturnValue:&shortValue];
        if (shortValue == SHRT_MAX) {
            *description = @"SHRT_MAX";
        } else if (shortValue == SHRT_MIN) {
            *description = @"SHRT_MIN";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(shortValue)];
        }
        
    } else if (strcmp(returnType, @encode(long)) == 0) {
        long longValue;
        [invocation getReturnValue:&longValue];
        if (longValue == NSNotFound) {
            *description = @"NSNotFound";
        } else if (longValue == LONG_MAX) {
            *description = @"LONG_MAX";
        } else if (longValue == LONG_MIN) {
            *description = @"LONG_MAX";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(longValue)];
        }
        
    } else if (strcmp(returnType, @encode(long long)) == 0) {
        long long longLongValue;
        [invocation getReturnValue:&longLongValue];
        if (longLongValue == LLONG_MAX) {
            *description = @"LLONG_MAX";
        } else if (longLongValue == LLONG_MIN) {
            *description = @"LLONG_MIN";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(longLongValue)];
        }
        
    } else if (strcmp(returnType, @encode(unsigned char)) == 0) {
        unsigned char ucharValue;
        [invocation getReturnValue:&ucharValue];
        if (ucharValue == UCHAR_MAX) {
            *description = @"UCHAR_MAX";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(ucharValue)];
        }
        
    } else if (strcmp(returnType, @encode(unsigned int)) == 0) {
        unsigned int uintValue;
        [invocation getReturnValue:&uintValue];
        if (uintValue == UINT_MAX) {
            *description = @"UINT_MAX";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(uintValue)];
        }
        
    } else if (strcmp(returnType, @encode(unsigned short)) == 0) {
        unsigned short ushortValue;
        [invocation getReturnValue:&ushortValue];
        if (ushortValue == USHRT_MAX) {
            *description = @"USHRT_MAX";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(ushortValue)];
        }
        
    } else if (strcmp(returnType, @encode(unsigned long)) == 0) {
        unsigned long ulongValue;
        [invocation getReturnValue:&ulongValue];
        if (ulongValue == ULONG_MAX) {
            *description = @"ULONG_MAX";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(ulongValue)];
        }
        
    } else if (strcmp(returnType, @encode(unsigned long long)) == 0) {
        unsigned long long ulongLongValue;
        [invocation getReturnValue:&ulongLongValue];
        if (ulongLongValue == ULONG_LONG_MAX) {
            *description = @"ULONG_LONG_MAX";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(ulongLongValue)];
        }
        
    } else if (strcmp(returnType, @encode(float)) == 0) {
        float floatValue;
        [invocation getReturnValue:&floatValue];
        if (floatValue == FLT_MAX) {
            *description = @"FLT_MAX";
        } else if (floatValue == FLT_MIN) {
            *description = @"FLT_MIN";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(floatValue)];
        }
        
    } else if (strcmp(returnType, @encode(double)) == 0) {
        double doubleValue;
        [invocation getReturnValue:&doubleValue];
        if (doubleValue == DBL_MAX) {
            *description = @"DBL_MAX";
        } else if (doubleValue == DBL_MIN) {
            *description = @"DBL_MIN";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(doubleValue)];
        }
        
    } else if (strcmp(returnType, @encode(BOOL)) == 0) {
        BOOL boolValue;
        [invocation getReturnValue:&boolValue];
        *description = boolValue ? @"YES" : @"NO";
        
    } else if (strcmp(returnType, @encode(SEL)) == 0) {
        SEL selValue;
        [invocation getReturnValue:&selValue];
        *description = [NSString stringWithFormat:@"SEL(%@)", NSStringFromSelector(selValue)];
        
    } else if (strcmp(returnType, @encode(Class)) == 0) {
        Class classValue;
        [invocation getReturnValue:&classValue];
        *description = [NSString stringWithFormat:@"<%@>", NSStringFromClass(classValue)];
        
    } else if (strcmp(returnType, @encode(CGPoint)) == 0) {
        CGPoint targetValue;
        [invocation getReturnValue:&targetValue];
        *description = NSStringFromCGPoint(targetValue);

    } else if (strcmp(returnType, @encode(CGVector)) == 0) {
        CGVector targetValue;
        [invocation getReturnValue:&targetValue];
        *description = NSStringFromCGVector(targetValue);

    } else if (strcmp(returnType, @encode(CGSize)) == 0) {
        CGSize targetValue;
        [invocation getReturnValue:&targetValue];
        *description = NSStringFromCGSize(targetValue);

    } else if (strcmp(returnType, @encode(CGRect)) == 0) {
        CGRect rectValue;
        [invocation getReturnValue:&rectValue];
        *description = NSStringFromCGRect(rectValue);
        
    } else if (strcmp(returnType, @encode(CGAffineTransform)) == 0) {
        CGAffineTransform rectValue;
        [invocation getReturnValue:&rectValue];
        *description = NSStringFromCGAffineTransform(rectValue);
        
    } else if (strcmp(returnType, @encode(UIEdgeInsets)) == 0) {
        UIEdgeInsets targetValue;
        [invocation getReturnValue:&targetValue];
        *description = NSStringFromUIEdgeInsets(targetValue);
        
    } else if (strcmp(returnType, @encode(UIOffset)) == 0) {
        UIOffset targetValue;
        [invocation getReturnValue:&targetValue];
        *description = NSStringFromUIOffset(targetValue);
        
    } else {
        if (@available(iOS 11.0, tvOS 11.0, *)) {
            if (strcmp(returnType, @encode(NSDirectionalEdgeInsets)) == 0) {
                NSDirectionalEdgeInsets targetValue;
                [invocation getReturnValue:&targetValue];
                *description = NSStringFromDirectionalEdgeInsets(targetValue);
                return;
            }
        }
        
        NSString *argType_string = [[NSString alloc] splk_safeInitWithUTF8String:returnType];
        if ([argType_string hasPrefix:@"@"] || [argType_string hasPrefix:@"^{"]) {
            __unsafe_unretained id returnObjValue;
            [invocation getReturnValue:&returnObjValue];
            
            if (returnObjValue) {
                *description = [NSString stringWithFormat:@"%@", returnObjValue];
                
                SPLKObject *parsedSPLKObj = [SPLKObject instanceWithObject:returnObjValue];
                *resultObject = parsedSPLKObj;
            } else {
                *description = @"nil";
            }
        } else {
            *description = [NSString stringWithFormat:SPLKLocalized(@"%@ was invoked successfully, but Lookin can't parse the return value:%@"), NSStringFromSelector(selector), argType_string];
        }
    }
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
