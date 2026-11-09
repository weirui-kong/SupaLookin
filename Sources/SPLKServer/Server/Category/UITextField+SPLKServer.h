#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  UITextField+SPLKServer.h
//  SPLKServer
//
//  Created by Li Kai on 2019/2/26.
//  https://lookin.work
//

#import <UIKit/UIKit.h>

@interface UITextField (SPLKServer)

@property(nonatomic, assign) CGFloat splk_fontSize;

- (NSString *)splk_fontName;

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
