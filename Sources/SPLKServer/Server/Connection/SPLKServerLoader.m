#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  SPLKServerLoader.m
//  SPLKServer
//
//  Created by Li Kai on 2019/1/15.
//  https://lookin.work
//

#import <UIKit/UIKit.h>
#import "SPLKExportManager.h"
#import "SPLKServerDefines.h"
#import "SPLKTraceManager.h"
#import "SPLKMultiplatformAdapter.h"

@interface SPLKServerLoader : NSObject

@end

@implementation SPLKServerLoader

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static SPLKServerLoader *instance = nil;
    dispatch_once(&onceToken,^{
        instance = [[super allocWithZone:NULL] init];
    });
    return instance;
}

// Swift isn't safe to run this early, so the Swift session starts once the app finishes launching.
+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserver:[self sharedInstance] selector:@selector(_handleDidFinishLaunching) name:UIApplicationDidFinishLaunchingNotification object:nil];
}

- (void)_handleDidFinishLaunching {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidFinishLaunchingNotification object:nil];
    NSLog(@"SPLKServer - Will launch. Framework version: %@", SPLK_SERVER_READABLE_VERSION);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleLocalInspect:) name:@"SPLK_2D" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleLocalInspect:) name:@"SPLK_3D" object:nil];
    [[NSNotificationCenter defaultCenter] addObserverForName:@"SPLK_Export" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [[SPLKExportManager sharedInstance] exportAndShare];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:@"SPLK_RelationSearch" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [[SPLKTraceManager sharedInstance] addSearchTarger:note.object];
    }];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleGetSPLKInfo:) name:@"GetSPLKInfo" object:nil];
    
    Class bootstrap = NSClassFromString(@"SPLKServerBootstrap");
    if ([bootstrap respondsToSelector:@selector(start)]) {
        [bootstrap performSelector:@selector(start)];
    } else {
        NSLog(@"SPLKServer - SPLKServerBootstrap is missing, so the server won't listen.");
    }
}

#pragma mark - Handler

- (void)_handleLocalInspect:(NSNotification *)note {
    UIAlertController  *alertController = [UIAlertController  alertControllerWithTitle:@"Lookin" message:@"Failed to run local inspection. The feature has been removed. Please use the computer version of Lookin or consider SDKs like FLEX for similar functionality."  preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction  = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:okAction];
    UIWindow *keyWindow = [SPLKMultiplatformAdapter keyWindow];
    UIViewController *rootViewController = [keyWindow rootViewController];
    [rootViewController presentViewController:alertController animated:YES completion:nil];
    
    NSLog(@"SPLKServer - Failed to run local inspection. The feature has been removed. Please use the computer version of Lookin or consider SDKs like FLEX for similar functionality.");
}

- (void)handleGetSPLKInfo:(NSNotification *)note {
    NSDictionary* userInfo = note.userInfo;
    if (!userInfo) {
        return;
    }
    NSMutableDictionary* infoWrapper = userInfo[@"infos"];
    if (![infoWrapper isKindOfClass:[NSMutableDictionary class]]) {
        NSLog(@"SPLKServer - GetSPLKInfo failed. Params invalid.");
        return;
    }
    infoWrapper[@"splkServerVersion"] = SPLK_SERVER_READABLE_VERSION;
}

@end

/// 这个类使得用户可以通过 NSClassFromString(@"SPLK") 来判断 SPLKServer 是否被编译进了项目里

@interface SPLK : NSObject

@end

@implementation SPLK

@end

#endif /* SHOULD_COMPILE_SPLK_SERVER */
