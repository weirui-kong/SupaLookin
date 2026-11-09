#ifdef SHOULD_COMPILE_SPLK_SHARED 

//
//  SPLKAttributesSection.m
//  Lookin
//
//  Created by Li Kai on 2019/3/2.
//  https://lookin.work
//



#import "SPLKAttributesSection.h"
#import "SPLKAttribute.h"

#import "NSArray+SPLK.h"

@implementation SPLKAttributesSection

#pragma mark - <NSCopying>

- (id)copyWithZone:(NSZone *)zone {
    SPLKAttributesSection *newSection = [[SPLKAttributesSection allocWithZone:zone] init];
    newSection.identifier = self.identifier;
    newSection.attributes = [self.attributes splk_map:^id(NSUInteger idx, SPLKAttribute *value) {
        return value.copy;
    }];
    return newSection;
}

#pragma mark - <NSCoding>

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.identifier forKey:@"identifier"];
    [aCoder encodeObject:self.attributes forKey:@"attributes"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        self.identifier = [aDecoder decodeObjectForKey:@"identifier"];
        self.attributes = [aDecoder decodeObjectForKey:@"attributes"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (BOOL)isUserCustom {
    return [self.identifier isEqualToString:SPLKAttrSec_UserCustom];
}

@end

#endif /* SHOULD_COMPILE_SPLK_SHARED */
