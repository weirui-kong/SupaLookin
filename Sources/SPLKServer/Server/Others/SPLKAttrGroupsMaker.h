#import <TargetConditionals.h>
#if TARGET_OS_IPHONE

//
//  SPLKAttrGroupsMaker.h
//  SPLKServer
//
//  Created by Li Kai on 2019/6/6.
//  https://lookin.work
//

#import "SPLKDefines.h"

@class SPLKAttributesGroup;

@interface SPLKAttrGroupsMaker : NSObject
    
+ (NSArray<SPLKAttributesGroup *> *)attrGroupsForLayer:(CALayer *)layer;

@end

#endif /* TARGET_OS_IPHONE */
