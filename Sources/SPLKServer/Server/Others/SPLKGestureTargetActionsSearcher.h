#ifdef SHOULD_COMPILE_SPLK_SERVER

//
//  SPLKGestureTargetActionsSearcher.h
//  SPLKServer
//
//  Created by likai.123 on 2023/9/11.
//

#import <UIKit/UIKit.h>

@class SPLKTwoTuple;

NS_ASSUME_NONNULL_BEGIN

@interface SPLKGestureTargetActionsSearcher : NSObject

/// 返回一个 UIGestureRecognizer 实例身上绑定的 target & action 信息
/// tuple.first => SPLKWeakContainer(包裹着 target)，tuple.second => action(方法名字符串)
+ (NSArray<SPLKTwoTuple *> *)getTargetActionsFromRecognizer:(UIGestureRecognizer *)recognizer;

@end

NS_ASSUME_NONNULL_END

#endif /* SHOULD_COMPILE_SPLK_SERVER */
