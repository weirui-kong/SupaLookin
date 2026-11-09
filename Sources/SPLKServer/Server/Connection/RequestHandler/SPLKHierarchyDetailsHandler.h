#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  SPLKHierarchyDetailsHandler.h
//  SPLKServer
//
//  Created by Li Kai on 2019/6/20.
//  https://lookin.work
//

#import <Foundation/Foundation.h>

@class SPLKDisplayItemDetail, SPLKStaticAsyncUpdateTasksPackage;

typedef void (^SPLKHierarchyDetailsHandler_ProgressBlock)(NSArray<SPLKDisplayItemDetail *> *details);
typedef void (^SPLKHierarchyDetailsHandler_FinishBlock)(void);

@interface SPLKHierarchyDetailsHandler : NSObject

/// packages 会按照 idx 从小到大的顺序被执行
/// 全部任务完成时，finishBlock 会被调用
/// 如果调用了 cancel，则 finishBlock 不会被执行
- (void)startWithPackages:(NSArray<SPLKStaticAsyncUpdateTasksPackage *> *)packages block:(SPLKHierarchyDetailsHandler_ProgressBlock)progressBlock finishedBlock:(SPLKHierarchyDetailsHandler_FinishBlock)finishBlock;

/// 取消所有任务
- (void)cancel;

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
