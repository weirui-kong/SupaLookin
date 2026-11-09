#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  NSObject+SPLKServer.m
//  SPLKServer
//
//  Created by Li Kai on 2019/4/21.
//  https://lookin.work
//

#import "NSObject+SPLK.h"
#import "NSObject+SPLKServer.h"
#import "SPLKServerDefines.h"
#import "SPLKObjectRegistry.h"
#import <objc/runtime.h>

@implementation NSObject (SPLKServer)

#pragma mark - oid

- (unsigned long)splk_registerOid {
    if (!self.splk_oid) {
        unsigned long oid = [[SPLKObjectRegistry sharedInstance] addObject:self];
        self.splk_oid = oid;
    }
    return self.splk_oid;
}

- (void)setSplk_oid:(unsigned long)splk_oid {
    [self splk_bindObject:@(splk_oid) forKey:@"splk_oid"];
}

- (unsigned long)splk_oid {
    NSNumber *number = [self splk_getBindObjectForKey:@"splk_oid"];
    return [number unsignedLongValue];
}

+ (NSObject *)splk_objectWithOid:(unsigned long)oid {
    return [[SPLKObjectRegistry sharedInstance] objectWithOid:oid];
}

#pragma mark - trace

- (void)setSplk_ivarTraces:(NSArray<SPLKIvarTrace *> *)splk_ivarTraces {
    [self splk_bindObject:splk_ivarTraces.copy forKey:@"splk_ivarTraces"];
    
    if (splk_ivarTraces) {
        [[NSObject splk_allObjectsWithTraces] addPointer:(void *)self];
    }
}

- (NSArray<SPLKIvarTrace *> *)splk_ivarTraces {
    return [self splk_getBindObjectForKey:@"splk_ivarTraces"];
}

- (void)setSplk_specialTrace:(NSString *)splk_specialTrace {
    [self splk_bindObject:splk_specialTrace forKey:@"splk_specialTrace"];
    if (splk_specialTrace) {
        [[NSObject splk_allObjectsWithTraces] addPointer:(void *)self];
    }
}
- (NSString *)splk_specialTrace {
    return [self splk_getBindObjectForKey:@"splk_specialTrace"];
}

+ (void)splk_clearAllObjectsTraces {
    [[[NSObject splk_allObjectsWithTraces] allObjects] enumerateObjectsUsingBlock:^(NSObject * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.splk_ivarTraces = nil;
        obj.splk_specialTrace = nil;
    }];
    [NSObject splk_allObjectsWithTraces].count = 0;
}

+ (NSPointerArray *)splk_allObjectsWithTraces {
    static dispatch_once_t onceToken;
    static NSPointerArray *splk_allObjectsWithTraces = nil;
    dispatch_once(&onceToken,^{
        splk_allObjectsWithTraces = [NSPointerArray weakObjectsPointerArray];
    });
    return splk_allObjectsWithTraces;
}

- (NSArray<NSString *> *)splk_classChainList {
    NSMutableArray<NSString *> *classChainList = [NSMutableArray array];
    Class currentClass = self.class;
    
    while (currentClass) {
        NSString *currentClassName = NSStringFromClass(currentClass);
        if (currentClassName) {
            [classChainList addObject:currentClassName];
        }
        currentClass = [currentClass superclass];
    }
    return classChainList.copy;
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
