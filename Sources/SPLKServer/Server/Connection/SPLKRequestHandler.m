#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  SPLKRequestHandler.m
//  SPLKServer
//
//  Created by Li Kai on 2019/1/15.
//  https://lookin.work
//

#import "SPLKRequestHandler.h"
#import "NSObject+SPLKServer.h"
#import "UIImage+SPLKServer.h"
#import "SPLKConnectionManager.h"
#import "SPLKConnectionResponseAttachment.h"
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
#import "SPLKAttrModificationPatchHandler.h"
#import "SPLKHierarchyDetailsHandler.h"
#import "SPLKStaticAsyncUpdateTask.h"

@interface SPLKRequestHandler ()

@property(nonatomic, strong) NSMutableSet<SPLKHierarchyDetailsHandler *> *activeDetailHandlers;

@end

@implementation SPLKRequestHandler {
    NSSet *_validRequestTypes;
}

- (instancetype)init {
    if (self = [super init]) {
        _validRequestTypes = [NSSet setWithObjects:@(SPLKRequestTypePing),
                              @(SPLKRequestTypeApp),
                              @(SPLKRequestTypeHierarchy),
                              @(SPLKRequestTypeInbuiltAttrModification),
                              @(SPLKRequestTypeCustomAttrModification),
                              @(SPLKRequestTypeAttrModificationPatch),
                              @(SPLKRequestTypeHierarchyDetails),
                              @(SPLKRequestTypeFetchObject),
                              @(SPLKRequestTypeAllAttrGroups),
                              @(SPLKRequestTypeAllSelectorNames),
                              @(SPLKRequestTypeInvokeMethod),
                              @(SPLKRequestTypeFetchImageViewImage),
                              @(SPLKRequestTypeModifyRecognizerEnable),
                              @(SPLKPush_CanceHierarchyDetails),
                              nil];
        
        self.activeDetailHandlers = [NSMutableSet set];
    }
    return self;
}

- (BOOL)canHandleRequestType:(uint32_t)requestType {
    if ([_validRequestTypes containsObject:@(requestType)]) {
        return YES;
    }
    return NO;
}

- (void)handleRequestType:(uint32_t)requestType tag:(uint32_t)tag object:(id)object {
    if (requestType == SPLKRequestTypePing) {
        SPLKConnectionResponseAttachment *responseAttachment = [SPLKConnectionResponseAttachment new];
        // 当 app 处于后台时，可能可以执行代码也可能不能执行代码，如果运气好了可以执行代码，则这里直接主动使用 appIsInBackground 标识 app 处于后台，不要让 Lookin 客户端傻傻地等待超时了
        if (![SPLKConnectionManager sharedInstance].applicationIsActive) {
            responseAttachment.appIsInBackground = YES;            
        }
        [[SPLKConnectionManager sharedInstance] respond:responseAttachment requestType:requestType tag:tag];
        
    } else if (requestType == SPLKRequestTypeApp) {
        // 请求可用设备信息
        if (![object isKindOfClass:[NSDictionary class]]) {
            [self _submitResponseWithError:SPLKErr_Inner requestType:requestType tag:tag];
            return;
        }
        NSDictionary<NSString *, id> *params = object;
        BOOL needImages = ((NSNumber *)params[@"needImages"]).boolValue;
        NSArray<NSNumber *> *localIdentifiers = params[@"local"];
        
        SPLKAppInfo *appInfo = [SPLKAppInfo currentInfoWithScreenshot:needImages icon:needImages localIdentifiers:localIdentifiers];
        
        SPLKConnectionResponseAttachment *responseAttachment = [SPLKConnectionResponseAttachment new];
        responseAttachment.data = appInfo;
        [[SPLKConnectionManager sharedInstance] respond:responseAttachment requestType:requestType tag:tag];
        
    } else if (requestType == SPLKRequestTypeHierarchy) {
        // 从 SPLKClient 1.0.4 开始有这个参数，之前是 nil
        NSString *clientVersion = nil;
        if ([object isKindOfClass:[NSDictionary class]]) {
            NSDictionary<NSString *, id> *params = object;
            NSString *version = params[@"clientVersion"];
            if ([version isKindOfClass:[NSString class]]) {
                clientVersion = version;
            }
        }
        
        SPLKConnectionResponseAttachment *responseAttachment = [SPLKConnectionResponseAttachment new];
        responseAttachment.data = [SPLKHierarchyInfo staticInfoWithSPLKVersion:clientVersion];
        [[SPLKConnectionManager sharedInstance] respond:responseAttachment requestType:requestType tag:tag];
        
    } else if (requestType == SPLKRequestTypeInbuiltAttrModification) {
        // 请求修改某个属性
        [SPLKInbuiltAttrModificationHandler handleModification:object completion:^(SPLKDisplayItemDetail *data, NSError *error) {
            SPLKConnectionResponseAttachment *attachment = [SPLKConnectionResponseAttachment new];
            if (error) {
                attachment.error = error;
            } else {
                attachment.data = data;
            }
            [[SPLKConnectionManager sharedInstance] respond:attachment requestType:requestType tag:tag];
        }];
        
    } else if (requestType == SPLKRequestTypeCustomAttrModification) {
        BOOL succ = [SPLKCustomAttrModificationHandler handleModification:object];
        if (succ) {
            [self _submitResponseWithData:nil requestType:requestType tag:tag];
        } else {
            [self _submitResponseWithError:SPLKErr_Inner requestType:requestType tag:tag];
        }
        
    } else if (requestType == SPLKRequestTypeAttrModificationPatch) {
        NSArray<SPLKStaticAsyncUpdateTask *> *tasks = object;
        NSUInteger dataTotalCount = tasks.count;
        [SPLKInbuiltAttrModificationHandler handlePatchWithTasks:tasks block:^(SPLKDisplayItemDetail *data) {
            SPLKConnectionResponseAttachment *attrAttachment = [SPLKConnectionResponseAttachment new];
            attrAttachment.data = data;
            attrAttachment.dataTotalCount = dataTotalCount;
            attrAttachment.currentDataCount = 1;
            [[SPLKConnectionManager sharedInstance] respond:attrAttachment requestType:SPLKRequestTypeAttrModificationPatch tag:tag];
        }];
        
    } else if (requestType == SPLKRequestTypeHierarchyDetails) {
        NSArray<SPLKStaticAsyncUpdateTasksPackage *> *packages = object;
        NSUInteger responsesDataTotalCount = [packages splk_reduceInteger:^NSInteger(NSInteger accumulator, NSUInteger idx, SPLKStaticAsyncUpdateTasksPackage *package) {
            accumulator += package.tasks.count;
            return accumulator;
        } initialAccumlator:0];
        
        SPLKHierarchyDetailsHandler *handler = [SPLKHierarchyDetailsHandler new];
        [self.activeDetailHandlers addObject:handler];
        
        [handler startWithPackages:packages block:^(NSArray<SPLKDisplayItemDetail *> *details) {
            SPLKConnectionResponseAttachment *attachment = [SPLKConnectionResponseAttachment new];
            attachment.data = details;
            attachment.dataTotalCount = responsesDataTotalCount;
            attachment.currentDataCount = details.count;
            [[SPLKConnectionManager sharedInstance] respond:attachment requestType:SPLKRequestTypeHierarchyDetails tag:tag];
            
        } finishedBlock:^{
            [self.activeDetailHandlers removeObject:handler];
        }];
        
    } else if (requestType == SPLKRequestTypeFetchObject) {
        unsigned long oid = ((NSNumber *)object).unsignedLongValue;
        NSObject *object = [NSObject splk_objectWithOid:oid];
        SPLKObject *splkObj = [SPLKObject instanceWithObject:object];
        
        SPLKConnectionResponseAttachment *attach = [SPLKConnectionResponseAttachment new];
        attach.data = splkObj;
        [[SPLKConnectionManager sharedInstance] respond:attach requestType:requestType tag:tag];
        
    } else if (requestType == SPLKRequestTypeAllAttrGroups) {
        unsigned long oid = ((NSNumber *)object).unsignedLongValue;
        CALayer *layer = (CALayer *)[NSObject splk_objectWithOid:oid];
        if (![layer isKindOfClass:[CALayer class]]) {
            [self _submitResponseWithError:SPLKErr_ObjNotFound requestType:SPLKRequestTypeAllAttrGroups tag:tag];
            return;
        }
        
        NSArray<SPLKAttributesGroup *> *list = [SPLKAttrGroupsMaker attrGroupsForLayer:layer];
        [self _submitResponseWithData:list requestType:SPLKRequestTypeAllAttrGroups tag:tag];
        
    } else if (requestType == SPLKRequestTypeAllSelectorNames) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            [self _submitResponseWithError:SPLKErr_Inner requestType:requestType tag:tag];
            return;
        }
        NSDictionary *params = object;
        Class targetClass = NSClassFromString(params[@"className"]);
        BOOL hasArg = [(NSNumber *)params[@"hasArg"] boolValue];
        if (!targetClass) {
            NSString *errorMsg = [NSString stringWithFormat:SPLKLocalized(@"Didn't find the class named \"%@\". Please input another class and try again."), object];
            [self _submitResponseWithError:SPLKErrorMake(errorMsg, @"") requestType:requestType tag:tag];
            return;
        }
        
        NSArray<NSString *> *selNames = [self _methodNameListForClass:targetClass hasArg:hasArg];
        [self _submitResponseWithData:selNames requestType:requestType tag:tag];
        
    } else if (requestType == SPLKRequestTypeInvokeMethod) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            [self _submitResponseWithError:SPLKErr_Inner requestType:requestType tag:tag];
            return;
        }
        NSDictionary *param = object;
        unsigned long oid = [param[@"oid"] unsignedLongValue];
        NSString *text = param[@"text"];
        if (!text.length) {
            [self _submitResponseWithError:SPLKErr_Inner requestType:requestType tag:tag];
            return;
        }
        NSObject *targerObj = [NSObject splk_objectWithOid:oid];
        if (!targerObj) {
            [self _submitResponseWithError:SPLKErr_ObjNotFound requestType:requestType tag:tag];
            return;
        }
        
        SEL targetSelector = NSSelectorFromString(text);
        if (targetSelector && [targerObj respondsToSelector:targetSelector]) {
            NSString *resultDescription;
            NSObject *resultObject;
            NSError *error;
            [self _handleInvokeWithObject:targerObj selector:targetSelector resultDescription:&resultDescription resultObject:&resultObject error:&error];
            if (error) {
                [self _submitResponseWithError:error requestType:requestType tag:tag];
                return;
            }
            NSMutableDictionary *responseData = [NSMutableDictionary dictionaryWithCapacity:2];
            if (resultDescription) {
                responseData[@"description"] = resultDescription;
            }
            if (resultObject) {
                responseData[@"object"] = resultObject;
            }
            [self _submitResponseWithData:responseData requestType:requestType tag:tag];
        } else {
            NSString *errMsg = [NSString stringWithFormat:SPLKLocalized(@"%@ doesn't have an instance method called \"%@\"."), NSStringFromClass(targerObj.class), text];
            [self _submitResponseWithError:SPLKErrorMake(errMsg, @"") requestType:requestType tag:tag];
        }
        
    } else if (requestType == SPLKPush_CanceHierarchyDetails) {
        [self.activeDetailHandlers enumerateObjectsUsingBlock:^(SPLKHierarchyDetailsHandler * _Nonnull handler, BOOL * _Nonnull stop) {
            [handler cancel];
        }];
        [self.activeDetailHandlers removeAllObjects];
        
    } else if (requestType == SPLKRequestTypeFetchImageViewImage) {
        if (![object isKindOfClass:[NSNumber class]]) {
            [self _submitResponseWithError:SPLKErr_Inner requestType:requestType tag:tag];
            return;
        }
        unsigned long imageViewOid = [(NSNumber *)object unsignedLongValue];
        UIImageView *imageView = (UIImageView *)[NSObject splk_objectWithOid:imageViewOid];
        if (!imageView) {
            [self _submitResponseWithError:SPLKErr_ObjNotFound requestType:requestType tag:tag];
            return;
        }
        if (![imageView isKindOfClass:[UIImageView class]]) {
            [self _submitResponseWithError:SPLKErr_Inner requestType:requestType tag:tag];
            return;
        }
        UIImage *image = imageView.image;
        NSData *imageData = [image splk_data];
        [self _submitResponseWithData:imageData requestType:requestType tag:tag];
    
    } else if (requestType == SPLKRequestTypeModifyRecognizerEnable) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            [self _submitResponseWithError:SPLKErr_Inner requestType:requestType tag:tag];
            return;
        }
        NSDictionary<NSString *, NSNumber *> *params = object;
        unsigned long recognizerOid = ((NSNumber *)params[@"oid"]).unsignedLongValue;
        BOOL shouldBeEnabled = ((NSNumber *)params[@"enable"]).boolValue;
        
        UIGestureRecognizer *recognizer = (UIGestureRecognizer *)[NSObject splk_objectWithOid:recognizerOid];
        if (!recognizer) {
            [self _submitResponseWithError:SPLKErr_ObjNotFound requestType:requestType tag:tag];
            return;
        }
        if (![recognizer isKindOfClass:[UIGestureRecognizer class]]) {
            [self _submitResponseWithError:SPLKErr_Inner requestType:requestType tag:tag];
            return;
        }
        recognizer.enabled = shouldBeEnabled;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // dispatch 以确保拿到的 enabled 是比较新的
            [self _submitResponseWithData:@(recognizer.enabled) requestType:requestType tag:tag];
        });
    }
}

- (NSArray<NSString *> *)_methodNameListForClass:(Class)aClass hasArg:(BOOL)hasArg {
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

- (void)_handleInvokeWithObject:(NSObject *)obj selector:(SEL)selector resultDescription:(NSString **)description resultObject:(SPLKObject **)resultObject error:(NSError **)error {
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

- (void)_submitResponseWithError:(NSError *)error requestType:(uint32_t)requestType tag:(uint32_t)tag {
    SPLKConnectionResponseAttachment *attachment = [SPLKConnectionResponseAttachment new];
    attachment.error = error;
    [[SPLKConnectionManager sharedInstance] respond:attachment requestType:requestType tag:tag];
}

- (void)_submitResponseWithData:(NSObject *)data requestType:(uint32_t)requestType tag:(uint32_t)tag {
    SPLKConnectionResponseAttachment *attachment = [SPLKConnectionResponseAttachment new];
    attachment.data = data;
    [[SPLKConnectionManager sharedInstance] respond:attachment requestType:requestType tag:tag];
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
