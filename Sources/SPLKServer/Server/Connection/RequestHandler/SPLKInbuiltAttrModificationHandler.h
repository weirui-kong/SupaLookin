#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  SPLKInbuiltAttrModificationHandler.h
//  SPLKServer
//
//  Created by Li Kai on 2019/6/12.
//  https://lookin.work
//

#import <Foundation/Foundation.h>

@class SPLKAttributeModification, SPLKDisplayItemDetail, SPLKStaticAsyncUpdateTask;

@interface SPLKInbuiltAttrModificationHandler : NSObject

+ (void)handleModification:(SPLKAttributeModification *)modification completion:(void (^)(SPLKDisplayItemDetail *data, NSError *error))completion;

+ (void)handlePatchWithTasks:(NSArray<SPLKStaticAsyncUpdateTask *> *)tasks block:(void (^)(SPLKDisplayItemDetail *data))block;

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
