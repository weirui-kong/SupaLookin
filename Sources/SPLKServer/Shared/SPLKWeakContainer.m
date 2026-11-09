#ifdef SHOULD_COMPILE_SPLK_SHARED 

//
//  SPLKWeakContainer.m
//  Lookin
//
//  Created by Li Kai on 2019/8/14.
//  https://lookin.work
//



#import "SPLKWeakContainer.h"

@implementation SPLKWeakContainer

+ (instancetype)containerWithObject:(id)object {
    SPLKWeakContainer *container = [SPLKWeakContainer new];
    container.object = object;
    return container;
}

- (NSUInteger)hash {
    return [self.object hash];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[SPLKWeakContainer class]]) {
        return NO;
    }
    SPLKWeakContainer *comparedObj = object;
    if ([self.object isEqual:comparedObj.object]) {
        return YES;
    }
    return NO;
}

@end

#endif /* SHOULD_COMPILE_SPLK_SHARED */
