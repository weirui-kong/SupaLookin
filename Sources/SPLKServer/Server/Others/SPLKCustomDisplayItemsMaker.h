#ifdef SHOULD_COMPILE_SPLK_SERVER

//
//  SPLKCustomDisplayItemsMaker.h
//  SPLKServer
//
//  Created by likai.123 on 2023/11/1.
//

#import <UIKit/UIKit.h>

@class SPLKDisplayItem;

@interface SPLKCustomDisplayItemsMaker : NSObject

- (instancetype)initWithLayer:(CALayer *)layer saveAttrSetter:(BOOL)saveAttrSetter;

- (NSArray<SPLKDisplayItem *> *)make;

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
