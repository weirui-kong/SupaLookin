#import <TargetConditionals.h>
#if TARGET_OS_IPHONE

//
//  UITableView+SPLKServer.h
//  SPLKServer
//
//  Created by Li Kai on 2019/9/5.
//  https://lookin.work
//

#import <UIKit/UIKit.h>

@interface UITableView (SPLKServer)

- (NSArray<NSNumber *> *)splk_numberOfRows;

@end

#endif /* TARGET_OS_IPHONE */
