#ifdef SHOULD_COMPILE_SPLK_SHARED 

//
//  SPLKIvarTrace.m
//  Lookin
//
//  Created by Li Kai on 2019/4/30.
//  https://lookin.work
//

#import "SPLKIvarTrace.h"

NSString *const SPLKIvarTraceRelationValue_Self = @"self";

@implementation SPLKIvarTrace

#pragma mark - Equal

- (NSUInteger)hash {
    return self.hostClassName.hash ^ self.ivarName.hash;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[SPLKIvarTrace class]]) {
        return NO;
    }
    SPLKIvarTrace *comparedObj = object;
    if ([self.hostClassName isEqualToString:comparedObj.hostClassName] && [self.ivarName isEqualToString:comparedObj.ivarName]) {
        return YES;
    }
    return NO;
}

#pragma mark - <NSCopying>
    
- (id)copyWithZone:(NSZone *)zone {
    SPLKIvarTrace *newTrace = [[SPLKIvarTrace allocWithZone:zone] init];
    newTrace.relation = self.relation;
    newTrace.hostClassName = self.hostClassName;
    newTrace.ivarName = self.ivarName;
    return newTrace;
}

#pragma mark - <NSCoding>

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.relation forKey:@"relation"];
    [aCoder encodeObject:self.hostClassName forKey:@"hostClassName"];
    [aCoder encodeObject:self.ivarName forKey:@"ivarName"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        self.relation = [aDecoder decodeObjectForKey:@"relation"];
        self.hostClassName = [aDecoder decodeObjectForKey:@"hostClassName"];
        self.ivarName = [aDecoder decodeObjectForKey:@"ivarName"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end

#endif /* SHOULD_COMPILE_SPLK_SHARED */
