#ifdef SHOULD_COMPILE_SPLK_SERVER
//
//  SPLKCustomAttrModificationHandler.h
//  SPLKServer
//
//  Created by likaimacbookhome on 2023/11/4.
//

#import <Foundation/Foundation.h>
#import "SPLKCustomAttrModification.h"

@interface SPLKCustomAttrModificationHandler : NSObject

/// 返回值表示是否修改成功（有成功调用 setter block 就算成功）
+ (BOOL)handleModification:(SPLKCustomAttrModification *)modification;

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
