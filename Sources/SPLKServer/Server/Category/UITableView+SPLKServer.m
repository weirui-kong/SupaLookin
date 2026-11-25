#import <TargetConditionals.h>
#if TARGET_OS_IPHONE

//
//  UITableView+SPLKServer.m
//  SPLKServer
//
//  Created by Li Kai on 2019/9/5.
//  https://lookin.work
//

#import "UITableView+SPLKServer.h"
#import "SPLKServerDefines.h"

@implementation UITableView (SPLKServer)

- (NSArray<NSNumber *> *)splk_numberOfRows {
    NSUInteger sectionsCount = MIN(self.numberOfSections, 10);
    NSArray<NSNumber *> *rowsCount = [NSArray splk_arrayWithCount:sectionsCount block:^id(NSUInteger idx) {
        return @([self numberOfRowsInSection:idx]);
    }];
    if (rowsCount.count == 0) {
        return nil;
    }
    return rowsCount;
}

@end

#endif /* TARGET_OS_IPHONE */
