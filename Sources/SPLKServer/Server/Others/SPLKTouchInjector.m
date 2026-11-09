#ifdef SHOULD_COMPILE_SPLK_SERVER

//
//  SPLKTouchInjector.m
//  SPLKServer
//
//  Created by Weirui Kong on 2026/11/10.
//

#import "SPLKTouchInjector.h"
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach/mach_time.h>
#import "SPLKMultiplatformAdapter.h"
#import "SPLKServerDefines.h"

// Private UIKit API, declared here and checked with respondsToSelector: before any call.
@interface UITouch (SPLKPrivate)
- (void)setWindow:(UIWindow *)window;
- (void)setView:(UIView *)view;
- (void)setPhase:(UITouchPhase)phase;
- (void)setTapCount:(NSUInteger)tapCount;
- (void)_setLocationInWindow:(CGPoint)location resetPrevious:(BOOL)resetPrevious;
- (void)setTimestamp:(NSTimeInterval)timestamp;
- (void)_setIsFirstTouchForView:(BOOL)firstTouchForView;
- (void)setIsTap:(BOOL)isTap;
- (void)_setHidEvent:(void *)event;
@end

@interface UIApplication (SPLKPrivate)
- (UIEvent *)_touchesEvent;
@end

@interface UIEvent (SPLKPrivate)
- (void)_clearTouches;
- (void)_addTouch:(UITouch *)touch forDelayedDelivery:(BOOL)delayed;
- (void)_setHIDEvent:(void *)event;
@end

typedef void *SPLKHIDEventRef;
typedef SPLKHIDEventRef (*SPLKCreateDigitizerEvent)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, double, double, double, double, double, Boolean, Boolean, uint32_t);
typedef SPLKHIDEventRef (*SPLKCreateFingerEvent)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, double, double, double, double, double, Boolean, Boolean, uint32_t);
typedef void (*SPLKAppendEvent)(SPLKHIDEventRef, SPLKHIDEventRef, uint32_t);
typedef void (*SPLKSetIntegerValue)(SPLKHIDEventRef, uint32_t, int);

static const uint32_t SPLKHIDTransducerTypeHand = 3;
static const uint32_t SPLKHIDDigitizerEventRange = 1 << 0;
static const uint32_t SPLKHIDDigitizerEventTouch = 1 << 1;
static const uint32_t SPLKHIDDigitizerEventPosition = 1 << 2;
// kIOHIDEventFieldDigitizerIsDisplayIntegrated: digitizer events (type 11), field 25.
static const uint32_t SPLKHIDFieldDigitizerIsDisplayIntegrated = (11 << 16) | 25;

static SPLKCreateDigitizerEvent splk_createDigitizerEvent;
static SPLKCreateFingerEvent splk_createFingerEvent;
static SPLKAppendEvent splk_appendEvent;
static SPLKSetIntegerValue splk_setIntegerValue;

@implementation SPLKTouchInjector

static NSMutableDictionary<NSNumber *, UITouch *> *splk_liveTouches;

+ (void)initialize {
    if (self != [SPLKTouchInjector class]) {
        return;
    }
    splk_liveTouches = [NSMutableDictionary dictionary];
    void *iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
    if (!iokit) {
        return;
    }
    splk_createDigitizerEvent = (SPLKCreateDigitizerEvent)dlsym(iokit, "IOHIDEventCreateDigitizerEvent");
    splk_createFingerEvent = (SPLKCreateFingerEvent)dlsym(iokit, "IOHIDEventCreateDigitizerFingerEvent");
    splk_appendEvent = (SPLKAppendEvent)dlsym(iokit, "IOHIDEventAppendEvent");
    splk_setIntegerValue = (SPLKSetIntegerValue)dlsym(iokit, "IOHIDEventSetIntegerValue");
}

+ (BOOL)isTouchAvailable {
    static BOOL available;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *missing = [self missingSymbols];
        available = missing.count == 0;
        if (!available) {
            NSLog(@"SPLKServer - Touch injection is unavailable. Missing: %@", [missing componentsJoinedByString:@", "]);
        }
    });
    return available;
}

+ (NSArray<NSString *> *)missingSymbols {
    NSMutableArray<NSString *> *missing = [NSMutableArray array];
    if (!splk_createDigitizerEvent) [missing addObject:@"IOHIDEventCreateDigitizerEvent"];
    if (!splk_createFingerEvent) [missing addObject:@"IOHIDEventCreateDigitizerFingerEvent"];
    if (!splk_appendEvent) [missing addObject:@"IOHIDEventAppendEvent"];
    if (!splk_setIntegerValue) [missing addObject:@"IOHIDEventSetIntegerValue"];
    NSArray<NSString *> *touchSelectors = @[@"setWindow:", @"setView:", @"setPhase:", @"setTapCount:", @"_setLocationInWindow:resetPrevious:",
                                            @"setTimestamp:", @"_setIsFirstTouchForView:", @"_setHidEvent:"];
    for (NSString *name in touchSelectors) {
        if (![UITouch instancesRespondToSelector:NSSelectorFromString(name)]) {
            [missing addObject:[@"-[UITouch " stringByAppendingFormat:@"%@]", name]];
        }
    }
    if (![UIApplication instancesRespondToSelector:@selector(_touchesEvent)]) {
        [missing addObject:@"-[UIApplication _touchesEvent]"];
    }
    // Checked on the class: the application may not have created its touches event yet.
    Class eventClass = NSClassFromString(@"UITouchesEvent");
    for (NSString *name in @[@"_clearTouches", @"_addTouch:forDelayedDelivery:", @"_setHIDEvent:"]) {
        if (![eventClass instancesRespondToSelector:NSSelectorFromString(name)]) {
            [missing addObject:[@"-[UITouchesEvent " stringByAppendingFormat:@"%@]", name]];
        }
    }
    return missing;
}

+ (NSError *)errorWithText:(NSString *)text {
    return [NSError errorWithDomain:SPLKErrorDomain code:SPLKErrCode_Default userInfo:@{NSLocalizedDescriptionKey:text}];
}

#pragma mark - Touches

+ (BOOL)injectTouch:(NSUInteger)touchID phase:(SPLKTouchInjectorPhase)phase location:(CGPoint)location error:(NSError **)error {
    if (![self isTouchAvailable]) {
        if (error) *error = [self errorWithText:@"Touch injection isn't available on this iOS version."];
        return NO;
    }
    UIWindow *window = [SPLKMultiplatformAdapter keyWindow];
    if (!window) {
        if (error) *error = [self errorWithText:@"There is no key window to touch."];
        return NO;
    }
    CGPoint point = CGPointMake(location.x * CGRectGetWidth(window.bounds), location.y * CGRectGetHeight(window.bounds));
    NSNumber *key = @(touchID);
    UITouch *touch = splk_liveTouches[key];

    if (phase == SPLKTouchInjectorPhaseBegan) {
        touch = [[UITouch alloc] init];
        // setWindow: resets other values, so it goes first.
        [touch setWindow:window];
        [touch setTapCount:1];
        [touch _setLocationInWindow:point resetPrevious:YES];
        [touch setView:[window hitTest:point withEvent:nil]];
        [touch setPhase:UITouchPhaseBegan];
        [touch _setIsFirstTouchForView:YES];
        // Gone from newer UIKit.
        if ([touch respondsToSelector:@selector(setIsTap:)]) {
            [touch setIsTap:NO];
        }
        [touch setTimestamp:[NSProcessInfo processInfo].systemUptime];
        SPLKHIDEventRef hidEvent = [self hidEventWithTouches:@[touch]];
        [touch _setHidEvent:hidEvent];
        CFRelease(hidEvent);
        splk_liveTouches[key] = touch;
    } else if (!touch) {
        if (error) *error = [self errorWithText:[NSString stringWithFormat:@"Touch %@ never began.", key]];
        return NO;
    } else {
        [touch setTimestamp:[NSProcessInfo processInfo].systemUptime];
        if (phase == SPLKTouchInjectorPhaseMoved) {
            [touch _setLocationInWindow:point resetPrevious:NO];
        }
        [touch setPhase:[self touchPhase:phase]];
    }

    // Every live touch rides in the event; the ones not named here are stationary.
    NSMutableArray<UITouch *> *touches = [NSMutableArray array];
    [splk_liveTouches enumerateKeysAndObjectsUsingBlock:^(NSNumber *otherKey, UITouch *other, BOOL *stop) {
        if (![otherKey isEqual:key] && other.phase != UITouchPhaseEnded && other.phase != UITouchPhaseCancelled) {
            [other setPhase:UITouchPhaseStationary];
        }
        [touches addObject:other];
    }];
    UIEvent *event = [[UIApplication sharedApplication] _touchesEvent];
    [event _clearTouches];
    SPLKHIDEventRef hidEvent = [self hidEventWithTouches:touches];
    [event _setHIDEvent:hidEvent];
    CFRelease(hidEvent);
    for (UITouch *each in touches) {
        [event _addTouch:each forDelayedDelivery:NO];
    }
    [[UIApplication sharedApplication] sendEvent:event];

    if (phase == SPLKTouchInjectorPhaseEnded || phase == SPLKTouchInjectorPhaseCancelled) {
        [splk_liveTouches removeObjectForKey:key];
        // Delivering the event doesn't move focus the way a real tap does.
        UIView *view = touch.view;
        if (phase == SPLKTouchInjectorPhaseEnded && view.canBecomeFirstResponder && !view.isFirstResponder) {
            [view becomeFirstResponder];
        }
    }
    return YES;
}

+ (UITouchPhase)touchPhase:(SPLKTouchInjectorPhase)phase {
    switch (phase) {
        case SPLKTouchInjectorPhaseBegan: return UITouchPhaseBegan;
        case SPLKTouchInjectorPhaseMoved: return UITouchPhaseMoved;
        case SPLKTouchInjectorPhaseStationary: return UITouchPhaseStationary;
        case SPLKTouchInjectorPhaseEnded: return UITouchPhaseEnded;
        case SPLKTouchInjectorPhaseCancelled: return UITouchPhaseCancelled;
    }
    return UITouchPhaseCancelled;
}

// UIKit's gesture recognizers only accept touch events backed by a digitizer HID event: a hand with one finger per touch.
+ (SPLKHIDEventRef)hidEventWithTouches:(NSArray<UITouch *> *)touches {
    uint64_t timestamp = mach_absolute_time();
    SPLKHIDEventRef hand = splk_createDigitizerEvent(kCFAllocatorDefault, timestamp, SPLKHIDTransducerTypeHand, 0, 0, SPLKHIDDigitizerEventTouch, 0, 0, 0, 0, 0, 0, false, true, 0);
    splk_setIntegerValue(hand, SPLKHIDFieldDigitizerIsDisplayIntegrated, 1);
    [touches enumerateObjectsUsingBlock:^(UITouch *touch, NSUInteger idx, BOOL *stop) {
        BOOL moved = touch.phase == UITouchPhaseMoved;
        BOOL touching = touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled;
        uint32_t mask = moved ? SPLKHIDDigitizerEventPosition : (SPLKHIDDigitizerEventRange | SPLKHIDDigitizerEventTouch);
        CGPoint point = [touch locationInView:touch.window];
        SPLKHIDEventRef finger = splk_createFingerEvent(kCFAllocatorDefault, timestamp, (uint32_t)idx + 1, 2, mask, point.x, point.y, 0, 0, 0, touching, touching, 0);
        splk_setIntegerValue(finger, SPLKHIDFieldDigitizerIsDisplayIntegrated, 1);
        splk_appendEvent(hand, finger, 0);
        CFRelease(finger);
    }];
    return hand;
}

#pragma mark - Responder

static __weak UIResponder *splk_capturedResponder;

+ (UIResponder *)firstResponder {
    splk_capturedResponder = nil;
    [[UIApplication sharedApplication] sendAction:@selector(splk_captureFirstResponder:) to:nil from:nil forEvent:nil];
    return splk_capturedResponder;
}

+ (BOOL)shakeWithError:(NSError **)error {
    UIResponder *responder = [self firstResponder] ?: [SPLKMultiplatformAdapter keyWindow];
    if (!responder) {
        if (error) *error = [self errorWithText:@"There is no key window to shake."];
        return NO;
    }
    [responder motionBegan:UIEventSubtypeMotionShake withEvent:nil];
    [responder motionEnded:UIEventSubtypeMotionShake withEvent:nil];
    return YES;
}

+ (id<UIKeyInput>)keyInputWithError:(NSError **)error {
    UIResponder *responder = [self firstResponder];
    if (![responder conformsToProtocol:@protocol(UIKeyInput)]) {
        if (error) *error = [self errorWithText:@"No text input has focus."];
        return nil;
    }
    return (id<UIKeyInput>)responder;
}

+ (BOOL)insertText:(NSString *)text error:(NSError **)error {
    id<UIKeyInput> input = [self keyInputWithError:error];
    [input insertText:text];
    return input != nil;
}

+ (BOOL)deleteBackwardWithError:(NSError **)error {
    id<UIKeyInput> input = [self keyInputWithError:error];
    [input deleteBackward];
    return input != nil;
}

@end

@implementation UIResponder (SPLKFirstResponder)

- (void)splk_captureFirstResponder:(id)sender {
    splk_capturedResponder = self;
}

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
