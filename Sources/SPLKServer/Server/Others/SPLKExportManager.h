#ifdef SHOULD_COMPILE_SPLK_SERVER 

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

#endif /* SHOULD_COMPILE_SPLK_SERVER */
