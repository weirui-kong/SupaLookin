#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  SPLKObjectRegistry.m
//  SPLKServer
//
//  Created by Li Kai on 2019/4/21.
//  https://lookin.work
//

#import "SPLKObjectRegistry.h"
#import <objc/runtime.h>

@interface SPLKObjectRegistry ()

@property(nonatomic, strong) NSPointerArray *data;

@end

@implementation SPLKObjectRegistry

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static SPLKObjectRegistry *instance = nil;
    dispatch_once(&onceToken,^{
        instance = [[super allocWithZone:NULL] init];
    });
    return instance;
}

+ (id)allocWithZone:(struct _NSZone *)zone{
    return [self sharedInstance];
}

- (instancetype)init {
    if (self = [super init]) {
        self.data = [NSPointerArray weakObjectsPointerArray];
        // index 为 0 用 Null 填充
        self.data.count = 1;
    }
    return self;
}

- (unsigned long)addObject:(NSObject *)object {
    if (!object) {
        return 0;
    }
    [self.data addPointer:(void *)object];
    return self.data.count - 1;
}

- (NSObject *)objectWithOid:(unsigned long)oid {
    if (self.data.count <= oid) {
        return nil;
    }
    id object = [self.data pointerAtIndex:oid];
    return object;
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
