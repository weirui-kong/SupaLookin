//
//  SPLKAttributeModification.h
//  Lookin
//
//  Created by Li Kai on 2018/11/20.
//  https://lookin.work
//



#import <Foundation/Foundation.h>
#import "SPLKAttrType.h"

@interface SPLKAttributeModification : NSObject <NSSecureCoding>

@property(nonatomic, assign) unsigned long targetOid;

@property(nonatomic, assign) SEL setterSelector;
@property(nonatomic, assign) SEL getterSelector;

@property(nonatomic, assign) SPLKAttrType attrType;
@property(nonatomic, strong) id value;

/// 1.0.4 开始加入这个参数
@property(nonatomic, copy) NSString *clientReadableVersion;

@end
