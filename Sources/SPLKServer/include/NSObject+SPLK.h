//
//  NSObject+SPLK.h
//  Lookin
//
//  Created by Li Kai on 2018/12/22.
//  https://lookin.work
//

#import "SPLKDefines.h"



#import <Foundation/Foundation.h>
#import "SPLKCodingValueType.h"

@interface NSObject (SPLK)

#pragma mark - Data Bind

/**
 给对象绑定上另一个对象以供后续取出使用，如果 object 传入 nil 则会清除该 key 之前绑定的对象
 
 @attention 被绑定的对象会被 strong 强引用
 @note 内部是使用 objc_setAssociatedObject / objc_getAssociatedObject 来实现
 
 @code
 - (UITableViewCell *)cellForIndexPath:(NSIndexPath *)indexPath {
 // 1）在这里给 button 绑定上 indexPath 对象
 [cell splk_bindObject:indexPath forKey:@"indexPath"];
 }
 
 - (void)didTapButton:(UIButton *)button {
 // 2）在这里取出被点击的 button 的 indexPath 对象
 NSIndexPath *indexPathTapped = [button splk_getBindObjectForKey:@"indexPath"];
 }
 @endcode
 */
- (void)splk_bindObject:(id)object forKey:(NSString *)key;

/**
 给对象绑定上另一个对象以供后续取出使用，但相比于 splk_bindObject:forKey:，该方法不会 strong 强引用传入的 object
 */
- (void)splk_bindObjectWeakly:(id)object forKey:(NSString *)key;

/**
 取出之前使用 bind 方法绑定的对象
 */
- (id)splk_getBindObjectForKey:(NSString *)key;

/**
 给对象绑定上一个 double 值以供后续取出使用
 */
- (void)splk_bindDouble:(double)doubleValue forKey:(NSString *)key;

/**
 取出之前用 splk_bindDouble:forKey: 绑定的值
 */
- (double)splk_getBindDoubleForKey:(NSString *)key;

/**
 给对象绑定上一个 BOOL 值以供后续取出使用
 */
- (void)splk_bindBOOL:(BOOL)boolValue forKey:(NSString *)key;

/**
 取出之前用 splk_bindBOOL:forKey: 绑定的值
 */
- (BOOL)splk_getBindBOOLForKey:(NSString *)key;

/**
 给对象绑定上一个 long 值以供后续取出使用
 */
- (void)splk_bindLong:(long)longValue forKey:(NSString *)key;

/**
 取出之前用 splk_bindLong:forKey: 绑定的值
 */
- (long)splk_getBindLongForKey:(NSString *)key;

/**
 给对象绑定上一个 CGPoint 值以供后续取出使用
 */
- (void)splk_bindPoint:(CGPoint)pointValue forKey:(NSString *)key;

/**
 取出之前用 splk_bindPoint:forKey: 绑定的值
 */
- (CGPoint)splk_getBindPointForKey:(NSString *)key;

/**
 移除之前使用 bind 方法绑定的对象
 */
- (void)splk_clearBindForKey:(NSString *)key;

@end

@interface NSObject (SPLK_Coding)

/// 会把 NSImage/UIImage 转换为 NSData，把 NSColor/UIColor 转换回 NSNumber 数组(rgba)
- (id)splk_encodedObjectWithType:(SPLKCodingValueType)type;
/// 会把 NSData 转换回 NSImage/UIImage，把 NSNumber 数组(rgba) 转换为 NSColor/UIColor
- (id)splk_decodedObjectWithType:(SPLKCodingValueType)type;

@end
