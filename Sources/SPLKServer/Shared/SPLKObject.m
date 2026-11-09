#ifdef SHOULD_COMPILE_SPLK_SHARED 

//
//  SPLKObject.m
//  Lookin
//
//  Created by Li Kai on 2019/4/20.
//  https://lookin.work
//

#import "SPLKObject.h"
#import "SPLKIvarTrace.h"
#import "NSArray+SPLK.h"
#import "NSString+SPLK.h"

#if TARGET_OS_IPHONE
#import "NSObject+SPLKServer.h"
#endif

@implementation SPLKObject

#if TARGET_OS_IPHONE
+ (instancetype)instanceWithObject:(NSObject *)object {
    SPLKObject *splkObj = [SPLKObject new];
    splkObj.oid = [object splk_registerOid];
    
    splkObj.memoryAddress = [NSString stringWithFormat:@"%p", object];
    splkObj.classChainList = [object splk_classChainList];
    
    splkObj.specialTrace = object.splk_specialTrace;
    splkObj.ivarTraces = object.splk_ivarTraces;
    
    return splkObj;
}
#endif

#pragma mark - <NSCopying>

- (id)copyWithZone:(NSZone *)zone {
    SPLKObject *newObject = [[SPLKObject allocWithZone:zone] init];
    newObject.oid = self.oid;
    newObject.memoryAddress = self.memoryAddress;
    newObject.classChainList = self.classChainList;
    newObject.specialTrace = self.specialTrace;
    newObject.ivarTraces = [self.ivarTraces splk_map:^id(NSUInteger idx, SPLKIvarTrace *value) {
        return value.copy;
    }];
    return newObject;
}

#pragma mark - <NSSecureCoding>

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:@(self.oid) forKey:@"oid"];
    [aCoder encodeObject:self.memoryAddress forKey:@"memoryAddress"];
    [aCoder encodeObject:self.classChainList forKey:@"classChainList"];
    [aCoder encodeObject:self.specialTrace forKey:@"specialTrace"];
    [aCoder encodeObject:self.ivarTraces forKey:@"ivarTraces"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        self.oid = [(NSNumber *)[aDecoder decodeObjectForKey:@"oid"] unsignedLongValue];
        self.memoryAddress = [aDecoder decodeObjectForKey:@"memoryAddress"];
        self.classChainList = [aDecoder decodeObjectForKey:@"classChainList"];
        self.specialTrace = [aDecoder decodeObjectForKey:@"specialTrace"];
        self.ivarTraces = [aDecoder decodeObjectForKey:@"ivarTraces"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (NSString *)rawClassName {
    return self.classChainList.firstObject;
}

@end

#endif /* SHOULD_COMPILE_SPLK_SHARED */
