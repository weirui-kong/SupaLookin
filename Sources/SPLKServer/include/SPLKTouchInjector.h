//
//  SPLKTouchInjector.h
//  SPLKServer
//
//  Created by Weirui Kong on 2026/11/10.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

// Same values as the v2 schema's Touch.Phase.
typedef NS_ENUM(NSInteger, SPLKTouchInjectorPhase) {
    SPLKTouchInjectorPhaseBegan = 1,
    SPLKTouchInjectorPhaseMoved = 2,
    SPLKTouchInjectorPhaseStationary = 3,
    SPLKTouchInjectorPhaseEnded = 4,
    SPLKTouchInjectorPhaseCancelled = 5,
};

// Replays input inside the app through UIKit's private touch and IOHIDEvent APIs. Implemented on
// iOS-family platforms in Debug only; call on the main thread.
@interface SPLKTouchInjector : NSObject

// Whether every private symbol touches need was found.
+ (BOOL)isTouchAvailable;

// `location` is normalized to the key window, 0–1 from its top left.
+ (BOOL)injectTouch:(NSUInteger)touchID
              phase:(SPLKTouchInjectorPhase)phase
           location:(CGPoint)location
              error:(NSError * _Nullable * _Nullable)error;

+ (BOOL)shakeWithError:(NSError * _Nullable * _Nullable)error;

+ (BOOL)insertText:(NSString *)text error:(NSError * _Nullable * _Nullable)error;

+ (BOOL)deleteBackwardWithError:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
