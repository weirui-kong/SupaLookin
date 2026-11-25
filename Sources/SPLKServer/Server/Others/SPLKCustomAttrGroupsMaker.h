#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
//
//  SPLKCustomAttrGroupsMaker.h
//  SPLKServer
//
//  Created by LikaiMacStudioWork on 2023/10/31.
//

#import "SPLKDefines.h"

@class SPLKAttributesGroup;

@interface SPLKCustomAttrGroupsMaker : NSObject

- (instancetype)initWithLayer:(CALayer *)layer;

- (void)execute;

- (NSArray<SPLKAttributesGroup *> *)getGroups;
- (NSString *)getCustomDisplayTitle;
- (NSString *)getDanceUISource;

+ (NSArray<SPLKAttributesGroup *> *)makeGroupsFromRawProperties:(NSArray *)rawProperties saveCustomSetter:(BOOL)saveCustomSetter;

@end

#endif /* TARGET_OS_IPHONE */
