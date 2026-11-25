#import <TargetConditionals.h>
#if TARGET_OS_IPHONE

//
//  SPLKExportManager.h
//  SPLKServer
//
//  Created by Li Kai on 2019/5/13.
//  https://lookin.work
//

#import <Foundation/Foundation.h>

@interface SPLKExportManager : NSObject

+ (instancetype)sharedInstance;

- (void)exportAndShare;

@end

#endif /* TARGET_OS_IPHONE */
