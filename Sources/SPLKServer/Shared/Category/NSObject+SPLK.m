#ifdef SHOULD_COMPILE_SPLK_SHARED 

//
//  NSObject+SPLK.m
//  Lookin
//
//  Created by Li Kai on 2018/12/22.
//  https://lookin.work
//

#import "NSObject+SPLK.h"
#import <objc/runtime.h>
#import "TargetConditionals.h"
#import "SPLKWeakContainer.h"

@implementation NSObject (SPLK)

#pragma mark - Data Bind

static char kAssociatedObjectKey_SPLKAllBindObjects;
- (NSMutableDictionary<id, id> *)splk_allBindObjects {
    NSMutableDictionary<id, id> *dict = objc_getAssociatedObject(self, &kAssociatedObjectKey_SPLKAllBindObjects);
    if (!dict) {
        dict = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &kAssociatedObjectKey_SPLKAllBindObjects, dict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return dict;
}

- (void)splk_bindObject:(id)object forKey:(NSString *)key {
    if (!key.length) {
        NSAssert(NO, @"");
        return;
    }
    @synchronized (self) {
        if (object) {
            [[self splk_allBindObjects] setObject:object forKey:key];
        } else {
            [[self splk_allBindObjects] removeObjectForKey:key];
        }
    }
}

- (id)splk_getBindObjectForKey:(NSString *)key {
    if (!key.length) {
        NSAssert(NO, @"");
        return nil;
    }
    @synchronized (self) {
        id storedObj = [[self splk_allBindObjects] objectForKey:key];
        if ([storedObj isKindOfClass:[SPLKWeakContainer class]]) {
            storedObj = [(SPLKWeakContainer *)storedObj object];
        }
        return storedObj;
    }
}

- (void)splk_bindObjectWeakly:(id)object forKey:(NSString *)key {
    if (!key.length) {
        NSAssert(NO, @"");
        return;
    }
    if (object) {
        SPLKWeakContainer *container = [[SPLKWeakContainer alloc] init];
        container.object = object;
        [self splk_bindObject:container forKey:key];
    } else {
        [self splk_bindObject:nil forKey:key];
    }
}

- (void)splk_bindDouble:(double)doubleValue forKey:(NSString *)key {
    [self splk_bindObject:@(doubleValue) forKey:key];
}

- (double)splk_getBindDoubleForKey:(NSString *)key {
    id object = [self splk_getBindObjectForKey:key];
    if ([object isKindOfClass:[NSNumber class]]) {
        double doubleValue = [(NSNumber *)object doubleValue];
        return doubleValue;
        
    } else {
        return 0.0;
    }
}

- (void)splk_bindBOOL:(BOOL)boolValue forKey:(NSString *)key {
    [self splk_bindObject:@(boolValue) forKey:key];
}

- (BOOL)splk_getBindBOOLForKey:(NSString *)key {
    id object = [self splk_getBindObjectForKey:key];
    if ([object isKindOfClass:[NSNumber class]]) {
        BOOL boolValue = [(NSNumber *)object boolValue];
        return boolValue;
        
    } else {
        return NO;
    }
}

- (void)splk_bindLong:(long)longValue forKey:(NSString *)key {
    [self splk_bindObject:@(longValue) forKey:key];
}

- (long)splk_getBindLongForKey:(NSString *)key {
    id object = [self splk_getBindObjectForKey:key];
    if ([object isKindOfClass:[NSNumber class]]) {
        long longValue = [(NSNumber *)object longValue];
        return longValue;
        
    } else {
        return 0;
    }
}

- (void)splk_bindPoint:(CGPoint)pointValue forKey:(NSString *)key {
#if TARGET_OS_IPHONE
    [self splk_bindObject:[NSValue valueWithCGPoint:pointValue] forKey:key];
#elif TARGET_OS_MAC
    NSPoint nsPoint = NSMakePoint(pointValue.x, pointValue.y);
    [self splk_bindObject:[NSValue valueWithPoint:nsPoint] forKey:key];
#endif
}

- (CGPoint)splk_getBindPointForKey:(NSString *)key {
    id object = [self splk_getBindObjectForKey:key];
    if ([object isKindOfClass:[NSValue class]]) {
#if TARGET_OS_IPHONE
        CGPoint pointValue = [(NSValue *)object CGPointValue];
#elif TARGET_OS_MAC
        NSPoint nsPointValue = [(NSValue *)object pointValue];
        CGPoint pointValue = CGPointMake(nsPointValue.x, nsPointValue.y);
#endif
        return pointValue;
    } else {
        return CGPointZero;
    }
}

- (void)splk_clearBindForKey:(NSString *)key {
    [self splk_bindObject:nil forKey:key];
}

@end

@implementation NSObject (SPLK_Coding)

- (id)splk_encodedObjectWithType:(SPLKCodingValueType)type {
    if (type == SPLKCodingValueTypeColor) {
        if ([self isKindOfClass:[SPLKColor class]]) {
            CGFloat r, g, b, a;
#if TARGET_OS_IPHONE
            CGFloat white;
            if ([(UIColor *)self getRed:&r green:&g blue:&b alpha:&a]) {
                // valid
            } else if ([(UIColor *)self getWhite:&white alpha:&a]) {
                r = white;
                g = white;
                b = white;
            } else {
                NSAssert(NO, @"");
                r = 0;
                g = 0;
                b = 0;
                a = 0;
            }
#elif TARGET_OS_MAC
            NSColor *color = [((NSColor *)self) colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
            [color getRed:&r green:&g blue:&b alpha:&a];
#endif
            NSArray<NSNumber *> *rgba = @[@(r), @(g), @(b), @(a)];
            return rgba;
            
        } else {
            NSAssert(NO, @"");
            return nil;
        }
        
    } else if (type == SPLKCodingValueTypeImage) {
#if TARGET_OS_IPHONE
        if ([self isKindOfClass:[UIImage class]]) {
            UIImage *image = (UIImage *)self;
            return UIImagePNGRepresentation(image);
            
        } else {
            NSAssert(NO, @"");
            return nil;
        }
#elif TARGET_OS_MAC
        if ([self isKindOfClass:[NSImage class]]) {
            NSImage *image = (NSImage *)self;
            return [image TIFFRepresentation];
            
        } else {
            NSAssert(NO, @"");
            return nil;
        }
#endif
        
    } else {
        return self;
    }
}

- (id)splk_decodedObjectWithType:(SPLKCodingValueType)type {
    if (type == SPLKCodingValueTypeColor) {
        if ([self isKindOfClass:[NSArray class]]) {
            NSArray<NSNumber *> *rgba = (NSArray *)self;
            CGFloat r = [rgba[0] doubleValue];
            CGFloat g = [rgba[1] doubleValue];
            CGFloat b = [rgba[2] doubleValue];
            CGFloat a = [rgba[3] doubleValue];
            SPLKColor *color = [SPLKColor colorWithRed:r green:g blue:b alpha:a];
            return color;
            
        } else {
            NSAssert(NO, @"");
            return nil;
        }
        
    } else if (type == SPLKCodingValueTypeImage) {
        if ([self isKindOfClass:[NSData class]]) {
            SPLKImage *image = [[SPLKImage alloc] initWithData:(NSData *)self];
            return image;
        } else {
            NSAssert(NO, @"");
            return nil;
        }
            
    } else {
        return self;
    }
}

@end

#endif /* SHOULD_COMPILE_SPLK_SHARED */
