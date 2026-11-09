#ifdef SHOULD_COMPILE_SPLK_SHARED 

//
//  SPLKAttributesSection.h
//  Lookin
//
//  Created by Li Kai on 2019/3/2.
//  https://lookin.work
//



#import <Foundation/Foundation.h>
#import "SPLKAttrIdentifiers.h"

@class SPLKAttribute;

typedef NS_ENUM (NSInteger, SPLKAttributesSectionStyle) {
    SPLKAttributesSectionStyleDefault,    // 每个 attr 独占一行
    SPLKAttributesSectionStyle0,  // frame 等卡片使用，前 4 个 attr 每行两个，之后每个 attr 在同一排，每个宽度为 1/4
    SPLKAttributesSectionStyle1,  // 第一个 attr 在第一排靠左，第二个 attr 在第一排靠右，之后的 attr 每个独占一行
    SPLKAttributesSectionStyle2   // 第一排独占一行，剩下的在同一行且均分宽度
};

@interface SPLKAttributesSection : NSObject <NSSecureCoding, NSCopying>

@property(nonatomic, copy) SPLKAttrSectionIdentifier identifier;

@property(nonatomic, copy) NSArray<SPLKAttribute *> *attributes;

- (BOOL)isUserCustom;

@end

#endif /* SHOULD_COMPILE_SPLK_SHARED */
