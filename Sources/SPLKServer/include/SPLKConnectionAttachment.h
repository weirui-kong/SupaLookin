#ifdef SHOULD_COMPILE_SPLK_SHARED 

//
//  SPLKConnectionAttachment.h
//  Lookin
//
//  Created by Li Kai on 2019/2/15.
//  https://lookin.work
//



#import <Foundation/Foundation.h>
#import "SPLKCodingValueType.h"

@interface SPLKConnectionAttachment : NSObject <NSSecureCoding>

@property(nonatomic, assign) SPLKCodingValueType dataType;

@property(nonatomic, strong) id data;

@end

#endif /* SHOULD_COMPILE_SPLK_SHARED */
