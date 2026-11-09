//
//  SPLKAttributesGroup.h
//  Lookin
//
//  Created by Li Kai on 2018/11/19.
//  https://lookin.work
//



#import <Foundation/Foundation.h>
#import "SPLKAttrIdentifiers.h"

@class SPLKAttributesSection;

/**
 In Lookin, a SPLKAttributesGroup instance will be rendered as a property card.
 
 When isUserCustom is false: two SPLKAttributesGroup instances will be regard as equal when they has the same SPLKAttrGroupIdentifier.
 When isUserCustom is true: two SPLKAttributesGroup instances will be regard as equal when they has the same title.
 当 isUserCustom 为 false 时：若两个 attrGroup 有相同的 SPLKAttrGroupIdentifier，则 isEqual: 返回 YES
 */
@interface SPLKAttributesGroup : NSObject <NSSecureCoding, NSCopying>

/// 只有在 identifier 为 custom 时，才存在该值
@property(nonatomic, copy) NSString *userCustomTitle;

@property(nonatomic, copy) SPLKAttrGroupIdentifier identifier;

@property(nonatomic, copy) NSArray<SPLKAttributesSection *> *attrSections;

/// 如果是 custom 则返回 userCustomTitle，如果不是 custom 则返回 identifier
- (NSString *)uniqueKey;

- (BOOL)isUserCustom;

@end
