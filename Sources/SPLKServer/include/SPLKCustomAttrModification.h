#ifdef SHOULD_COMPILE_SPLK_SHARED
//
//  SPLKCustomAttrModification.h
//  SPLKServer
//
//  Created by likaimacbookhome on 2023/11/4.
//

#import <Foundation/Foundation.h>
#import "SPLKAttrType.h"

@interface SPLKCustomAttrModification : NSObject <NSSecureCoding>

@property(nonatomic, assign) SPLKAttrType attrType;
@property(nonatomic, copy) NSString *customSetterID;
@property(nonatomic, strong) id value;

@end

#endif /* SHOULD_COMPILE_SPLK_SHARED */
