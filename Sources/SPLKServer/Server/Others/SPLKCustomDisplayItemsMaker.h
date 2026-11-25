#import <TargetConditionals.h>
#if TARGET_OS_IPHONE

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

#endif /* TARGET_OS_IPHONE */
