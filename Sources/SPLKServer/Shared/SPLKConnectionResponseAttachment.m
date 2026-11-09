#ifdef SHOULD_COMPILE_SPLK_SHARED 

//
//  SPLKConnectionResponse.m
//  Lookin
//
//  Created by Li Kai on 2019/1/15.
//  https://lookin.work
//



#import "SPLKConnectionResponseAttachment.h"
#import "SPLKDefines.h"

@interface SPLKConnectionResponseAttachment ()

@end

@implementation SPLKConnectionResponseAttachment

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
    [aCoder encodeInt:self.splkServerVersion forKey:@"lookinServerVersion"];
    [aCoder encodeObject:self.error forKey:@"error"];
    [aCoder encodeObject:@(self.dataTotalCount) forKey:@"dataTotalCount"];
    [aCoder encodeObject:@(self.currentDataCount) forKey:@"currentDataCount"];
    [aCoder encodeBool:self.appIsInBackground forKey:@"appIsInBackground"];
}

- (instancetype)init {
    if (self = [super init]) {
        self.splkServerVersion = SPLK_SERVER_VERSION;
        self.dataTotalCount = 0;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        self.splkServerVersion = [aDecoder decodeIntForKey:@"lookinServerVersion"];
        self.error = [aDecoder decodeObjectForKey:@"error"];
        self.dataTotalCount = [[aDecoder decodeObjectForKey:@"dataTotalCount"] unsignedIntegerValue];
        self.currentDataCount = [[aDecoder decodeObjectForKey:@"currentDataCount"] unsignedIntegerValue];
        self.appIsInBackground = [aDecoder decodeBoolForKey:@"appIsInBackground"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (instancetype)attachmentWithError:(NSError *)error {
    SPLKConnectionResponseAttachment *attachment = [SPLKConnectionResponseAttachment new];
    attachment.error = error;
    return attachment;
}

@end

#endif /* SHOULD_COMPILE_SPLK_SHARED */
