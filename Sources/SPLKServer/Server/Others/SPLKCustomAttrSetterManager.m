#ifdef SHOULD_COMPILE_SPLK_SERVER
//
//  SPLKCustomAttrSetterManager.m
//  SPLKServer
//
//  Created by likai.123 on 2023/11/4.
//

#import "SPLKCustomAttrSetterManager.h"

@interface SPLKCustomAttrSetterManager ()

@property(nonatomic, strong) NSMutableDictionary *settersMap;

@end

@implementation SPLKCustomAttrSetterManager

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static SPLKCustomAttrSetterManager *instance = nil;
    dispatch_once(&onceToken,^{
        instance = [[super allocWithZone:NULL] init];
    });
    return instance;
}

+ (id)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.settersMap = [NSMutableDictionary new];
    }
    return self;
}

- (void)removeAll {
    [self.settersMap removeAllObjects];
}

- (void)saveStringSetter:(nonnull SPLKStringSetter)setter uniqueID:(nonnull NSString *)uniqueID {
    self.settersMap[uniqueID] = setter;
}

- (nullable SPLKStringSetter)getStringSetterWithID:(nonnull NSString *)uniqueID {
    return self.settersMap[uniqueID];
}

- (void)saveNumberSetter:(SPLKNumberSetter)setter uniqueID:(NSString *)uniqueID {
    self.settersMap[uniqueID] = setter;
}

- (nullable SPLKNumberSetter)getNumberSetterWithID:(NSString *)uniqueID {
    return self.settersMap[uniqueID];
}

- (void)saveBoolSetter:(SPLKBoolSetter)setter uniqueID:(NSString *)uniqueID {
    self.settersMap[uniqueID] = setter;
}

- (SPLKBoolSetter)getBoolSetterWithID:(NSString *)uniqueID {
    return self.settersMap[uniqueID];
}

- (void)saveColorSetter:(SPLKColorSetter)setter uniqueID:(NSString *)uniqueID {
    self.settersMap[uniqueID] = setter;
}

- (SPLKColorSetter)getColorSetterWithID:(NSString *)uniqueID {
    return self.settersMap[uniqueID];
}

- (void)saveEnumSetter:(SPLKEnumSetter)setter uniqueID:(NSString *)uniqueID {
    self.settersMap[uniqueID] = setter;
}

- (SPLKEnumSetter)getEnumSetterWithID:(NSString *)uniqueID {
    return self.settersMap[uniqueID];
}

- (void)saveRectSetter:(SPLKRectSetter)setter uniqueID:(NSString *)uniqueID {
    self.settersMap[uniqueID] = setter;
}

- (SPLKRectSetter)getRectSetterWithID:(NSString *)uniqueID {
    return self.settersMap[uniqueID];
}

- (void)saveSizeSetter:(SPLKSizeSetter)setter uniqueID:(NSString *)uniqueID {
    self.settersMap[uniqueID] = setter;
}

- (SPLKSizeSetter)getSizeSetterWithID:(NSString *)uniqueID {
    return self.settersMap[uniqueID];
}

- (void)savePointSetter:(SPLKPointSetter)setter uniqueID:(NSString *)uniqueID {
    self.settersMap[uniqueID] = setter;
}

- (SPLKPointSetter)getPointSetterWithID:(NSString *)uniqueID {
    return self.settersMap[uniqueID];
}

- (void)saveInsetsSetter:(SPLKInsetsSetter)setter uniqueID:(NSString *)uniqueID {
    self.settersMap[uniqueID] = setter;
}

- (SPLKInsetsSetter)getInsetsSetterWithID:(NSString *)uniqueID {
    return self.settersMap[uniqueID];
}

@end
#endif /* SHOULD_COMPILE_SPLK_SERVER */
