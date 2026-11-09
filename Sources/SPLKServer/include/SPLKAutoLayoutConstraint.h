#ifdef SHOULD_COMPILE_SPLK_SHARED 

//
//  SPLKAutoLayoutConstraint.h
//  Lookin
//
//  Created by Li Kai on 2019/9/28.
//  https://lookin.work
//



#import "SPLKDefines.h"

@class SPLKObject;

typedef NS_ENUM(NSInteger, SPLKConstraintItemType) {
    SPLKConstraintItemTypeUnknown,
    SPLKConstraintItemTypeNil,
    SPLKConstraintItemTypeView,
    SPLKConstraintItemTypeSelf,
    SPLKConstraintItemTypeSuper,
    SPLKConstraintItemTypeLayoutGuide
};

@interface SPLKAutoLayoutConstraint : NSObject <NSSecureCoding>

#if TARGET_OS_IPHONE
+ (instancetype)instanceFromNSConstraint:(NSLayoutConstraint *)constraint isEffective:(BOOL)isEffective firstItemType:(SPLKConstraintItemType)firstItemType secondItemType:(SPLKConstraintItemType)secondItemType;
#endif

@property(nonatomic, assign) BOOL effective;
@property(nonatomic, assign) BOOL active;
@property(nonatomic, assign) BOOL shouldBeArchived;
@property(nonatomic, strong) SPLKObject *firstItem;
@property(nonatomic, assign) SPLKConstraintItemType firstItemType;
/// iOS 里的 NSLayoutAttribute，注意 iOS 和 macOS 虽然都有 NSLayoutAttribute 但是 value 非常不同，因此这里使用 NSInteger 避免混淆
@property(nonatomic, assign) NSInteger firstAttribute;
@property(nonatomic, assign) NSLayoutRelation relation;
@property(nonatomic, strong) SPLKObject *secondItem;
@property(nonatomic, assign) SPLKConstraintItemType secondItemType;
/// iOS 里的 NSLayoutAttribute，注意 iOS 和 macOS 虽然都有 NSLayoutAttribute 但是 value 非常不同，因此这里使用 NSInteger 避免混淆
@property(nonatomic, assign) NSInteger secondAttribute;
@property(nonatomic, assign) CGFloat multiplier;
@property(nonatomic, assign) CGFloat constant;
@property(nonatomic, assign) CGFloat priority;
@property(nonatomic, copy) NSString *identifier;

@end

#endif /* SHOULD_COMPILE_SPLK_SHARED */
