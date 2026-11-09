#ifdef SHOULD_COMPILE_SPLK_SERVER 

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

#endif /* SHOULD_COMPILE_SPLK_SERVER */
