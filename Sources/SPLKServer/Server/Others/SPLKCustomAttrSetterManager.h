#ifdef SHOULD_COMPILE_SPLK_SERVER
//
//  SPLKCustomAttrSetterManager.h
//  SPLKServer
//
//  Created by likai.123 on 2023/11/4.
//

#import <UIKit/UIKit.h>

typedef void(^SPLKStringSetter)(NSString *);
typedef void(^SPLKNumberSetter)(NSNumber *);
typedef void(^SPLKBoolSetter)(BOOL);
typedef void(^SPLKColorSetter)(UIColor *);
typedef void(^SPLKEnumSetter)(NSString *);
typedef void(^SPLKRectSetter)(CGRect);
typedef void(^SPLKSizeSetter)(CGSize);
typedef void(^SPLKPointSetter)(CGPoint);
typedef void(^SPLKInsetsSetter)(UIEdgeInsets);

@interface SPLKCustomAttrSetterManager : NSObject

+ (instancetype)sharedInstance;

- (void)removeAll;

- (void)saveStringSetter:(SPLKStringSetter)setter uniqueID:(NSString *)uniqueID;
- (SPLKStringSetter)getStringSetterWithID:(NSString *)uniqueID;

- (void)saveNumberSetter:(SPLKNumberSetter)setter uniqueID:(NSString *)uniqueID;
- (SPLKNumberSetter)getNumberSetterWithID:(NSString *)uniqueID;

- (void)saveBoolSetter:(SPLKBoolSetter)setter uniqueID:(NSString *)uniqueID;
- (SPLKBoolSetter)getBoolSetterWithID:(NSString *)uniqueID;

- (void)saveColorSetter:(SPLKColorSetter)setter uniqueID:(NSString *)uniqueID;
- (SPLKColorSetter)getColorSetterWithID:(NSString *)uniqueID;

- (void)saveEnumSetter:(SPLKEnumSetter)setter uniqueID:(NSString *)uniqueID;
- (SPLKEnumSetter)getEnumSetterWithID:(NSString *)uniqueID;

- (void)saveRectSetter:(SPLKRectSetter)setter uniqueID:(NSString *)uniqueID;
- (SPLKRectSetter)getRectSetterWithID:(NSString *)uniqueID;

- (void)saveSizeSetter:(SPLKSizeSetter)setter uniqueID:(NSString *)uniqueID;
- (SPLKSizeSetter)getSizeSetterWithID:(NSString *)uniqueID;

- (void)savePointSetter:(SPLKPointSetter)setter uniqueID:(NSString *)uniqueID;
- (SPLKPointSetter)getPointSetterWithID:(NSString *)uniqueID;

- (void)saveInsetsSetter:(SPLKInsetsSetter)setter uniqueID:(NSString *)uniqueID;
- (SPLKInsetsSetter)getInsetsSetterWithID:(NSString *)uniqueID;

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
