#ifdef SHOULD_COMPILE_SPLK_SHARED 

//
//  SPLKConnectionAttachment.m
//  Lookin
//
//  Created by Li Kai on 2019/2/15.
//  https://lookin.work
//



#import "SPLKConnectionAttachment.h"
#import "SPLKDefines.h"
#import "NSObject+SPLK.h"

static NSString * const Key_Data = @"0";
static NSString * const Key_DataType = @"1";

@interface SPLKConnectionAttachment ()

@end

@implementation SPLKConnectionAttachment

- (instancetype)init {
    if (self = [super init]) {
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    
    [aCoder encodeObject:[self.data splk_encodedObjectWithType:self.dataType] forKey:Key_Data];
    [aCoder encodeInteger:self.dataType forKey:Key_DataType];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        self.dataType = [aDecoder decodeIntegerForKey:Key_DataType];
        self.data = [[aDecoder decodeObjectForKey:Key_Data] splk_decodedObjectWithType:self.dataType];
    }
    return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end

#endif /* SHOULD_COMPILE_SPLK_SHARED */
