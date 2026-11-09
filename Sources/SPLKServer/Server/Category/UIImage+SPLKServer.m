#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  UIImage+SPLKServer.m
//  SPLKServer
//
//  Created by Li Kai on 2019/5/14.
//  https://lookin.work
//

#import <objc/runtime.h>
#import "UIImage+SPLKServer.h"
#import "SPLKServerDefines.h"

@implementation UIImage (SPLKServer)

#ifdef SPLK_SERVER_DISABLE_HOOK

- (void)setSplk_imageSourceName:(NSString *)splk_imageSourceName {
}

- (NSString *)splk_imageSourceName {
    return nil;
}

#else

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method oriMethod = class_getClassMethod([self class], @selector(imageNamed:));
        Method newMethod = class_getClassMethod([self class], @selector(splk_imageNamed:));
        method_exchangeImplementations(oriMethod, newMethod);
        
        oriMethod = class_getClassMethod([self class], @selector(imageWithContentsOfFile:));
        newMethod = class_getClassMethod([self class], @selector(splk_imageWithContentsOfFile:));
        method_exchangeImplementations(oriMethod, newMethod);
        
        oriMethod = class_getClassMethod([self class], @selector(imageNamed:inBundle:compatibleWithTraitCollection:));
        newMethod = class_getClassMethod([self class], @selector(splk_imageNamed:inBundle:compatibleWithTraitCollection:));
        method_exchangeImplementations(oriMethod, newMethod);
        
        if (@available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)) {
            oriMethod = class_getClassMethod([self class], @selector(imageNamed:inBundle:withConfiguration:));
            newMethod = class_getClassMethod([self class], @selector(splk_imageNamed:inBundle:withConfiguration:));
            method_exchangeImplementations(oriMethod, newMethod);
        }
    });
}

+ (nullable UIImage *)splk_imageNamed:(NSString *)name inBundle:(nullable NSBundle *)bundle withConfiguration:(nullable UIImageConfiguration *)configuration API_AVAILABLE(ios(13.0),tvos(13.0),watchos(6.0))
{
    UIImage *image = [self splk_imageNamed:name inBundle:bundle withConfiguration:configuration];
    image.splk_imageSourceName = name;
    return image;
}

+ (nullable UIImage *)splk_imageNamed:(NSString *)name inBundle:(nullable NSBundle *)bundle compatibleWithTraitCollection:(nullable UITraitCollection *)traitCollection API_AVAILABLE(ios(8.0))
{
    UIImage *image = [self splk_imageNamed:name inBundle:bundle compatibleWithTraitCollection:traitCollection];
    image.splk_imageSourceName = name;
    return image;
}

+ (UIImage *)splk_imageNamed:(NSString *)name {
    UIImage *image = [self splk_imageNamed:name];
    image.splk_imageSourceName = name;
    return image;
}

+ (UIImage *)splk_imageWithContentsOfFile:(NSString *)path {
    UIImage *image = [self splk_imageWithContentsOfFile:path];
    
    NSString *fileName = [[path componentsSeparatedByString:@"/"].lastObject componentsSeparatedByString:@"."].firstObject;
    image.splk_imageSourceName = fileName;
    return image;
}

- (void)setSplk_imageSourceName:(NSString *)splk_imageSourceName {
    [self splk_bindObject:splk_imageSourceName.copy forKey:@"splk_imageSourceName"];
}

- (NSString *)splk_imageSourceName {
    return [self splk_getBindObjectForKey:@"splk_imageSourceName"];
}

#endif /* SPLK_SERVER_DISABLE_HOOK */

- (NSData *)splk_data {
    return UIImagePNGRepresentation(self);
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
