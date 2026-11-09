#ifdef SHOULD_COMPILE_SPLK_SERVER 

//
//  SPLKServer.m
//  SPLKServer
//
//  Created by Li Kai on 2018/8/5.
//  https://lookin.work
//

#import "SPLKConnectionManager.h"
#import "SPLK_PTChannel.h"
#import "SPLKRequestHandler.h"
#import "SPLKConnectionResponseAttachment.h"
#import "SPLKExportManager.h"
#import "SPLKServerDefines.h"
#import "SPLKTraceManager.h"
#import "SPLKMultiplatformAdapter.h"

NSString *const SPLKConnectionDidEndNotificationName = @"SPLKConnectionDidEndNotificationName";

@interface SPLKConnectionManager () <SPLK_PTChannelDelegate>

@property(nonatomic, weak) SPLK_PTChannel *peerChannel_;

@property(nonatomic, strong) SPLKRequestHandler *requestHandler;

@end

@implementation SPLKConnectionManager

+ (instancetype)sharedInstance {
    static SPLKConnectionManager *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SPLKConnectionManager alloc] init];
    });
    return sharedInstance;
}

+ (void)load {
    // 触发 init 方法
    [SPLKConnectionManager sharedInstance];
}

- (instancetype)init {
    if (self = [super init]) {
        NSLog(@"SPLKServer - Will launch. Framework version: %@", SPLK_SERVER_READABLE_VERSION);
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleApplicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleWillResignActiveNotification) name:UIApplicationWillResignActiveNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleLocalInspect:) name:@"SPLK_2D" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleLocalInspect:) name:@"SPLK_3D" object:nil];
        [[NSNotificationCenter defaultCenter] addObserverForName:@"SPLK_Export" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            [[SPLKExportManager sharedInstance] exportAndShare];
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:@"SPLK_RelationSearch" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            [[SPLKTraceManager sharedInstance] addSearchTarger:note.object];
        }];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleGetSPLKInfo:) name:@"GetSPLKInfo" object:nil];
        
        self.requestHandler = [SPLKRequestHandler new];
    }
    return self;
}

- (void)_handleWillResignActiveNotification {
    self.applicationIsActive = NO;
    
    if (self.peerChannel_ && ![self.peerChannel_ isConnected]) {
        [self.peerChannel_ close];
        self.peerChannel_ = nil;
    }
}

- (void)_handleApplicationDidBecomeActive {
    self.applicationIsActive = YES;
    [self searchPortToListenIfNoConnection];
}

- (void)searchPortToListenIfNoConnection {
    if ([self.peerChannel_ isConnected]) {
        NSLog(@"SPLKServer - Abort to search ports. Already has connected channel.");
        return;
    }
    NSLog(@"SPLKServer - Searching port to listen...");
    [self.peerChannel_ close];
    self.peerChannel_ = nil;
    
    if ([self isiOSAppOnMac]) {
        [self _tryToListenOnPortFrom:SPLKSimulatorIPv4PortNumberStart to:SPLKSimulatorIPv4PortNumberEnd current:SPLKSimulatorIPv4PortNumberStart];
    } else {
        [self _tryToListenOnPortFrom:SPLKUSBDeviceIPv4PortNumberStart to:SPLKUSBDeviceIPv4PortNumberEnd current:SPLKUSBDeviceIPv4PortNumberStart];
    }
}

- (BOOL)isiOSAppOnMac {
#if TARGET_OS_SIMULATOR
    return YES;
#else
    if (@available(iOS 14.0, *)) {
        // isiOSAppOnMac 这个 API 看似在 iOS 14.0 上可用，但其实在 iOS 14 beta 上是不存在的、有 unrecognized selector 问题，因此这里要用 respondsToSelector 做一下保护
        NSProcessInfo *info = [NSProcessInfo processInfo];
        if ([info respondsToSelector:@selector(isiOSAppOnMac)] && [info isiOSAppOnMac]) {
            return YES;
        } else if ([info respondsToSelector:@selector(isMacCatalystApp)] && [info isMacCatalystApp]) {
            return YES;
        } else {
            return NO;
        }
    } else if (@available(iOS 13.0, tvOS 13.0, *)) {
        return [NSProcessInfo processInfo].isMacCatalystApp;
    }
    return NO;
#endif
}

- (void)_tryToListenOnPortFrom:(int)fromPort to:(int)toPort current:(int)currentPort  {
    SPLK_PTChannel *channel = [SPLK_PTChannel channelWithDelegate:self];
    channel.targetPort = currentPort;
    [channel listenOnPort:currentPort IPv4Address:INADDR_LOOPBACK callback:^(NSError *error) {
        if (error) {
            if (error.code == 48) {
                // 该地址已被占用
            } else {
                // 未知失败
            }
            
            if (currentPort < toPort) {
                // 尝试下一个端口
                NSLog(@"SPLKServer - 127.0.0.1:%d is unavailable(%@). Will try anothor address ...", currentPort, error);
                [self _tryToListenOnPortFrom:fromPort to:toPort current:(currentPort + 1)];
            } else {
                // 所有端口都尝试完毕，全部失败
                NSLog(@"SPLKServer - 127.0.0.1:%d is unavailable(%@).", currentPort, error);
                NSLog(@"SPLKServer - Connect failed in the end.");
            }
            
        } else {
            // 成功
            NSLog(@"SPLKServer - Connected successfully on 127.0.0.1:%d", currentPort);
            // 此时 peerChannel_ 状态为 listening
            self.peerChannel_ = channel;
        }
    }];
}

- (void)dealloc {
    if (self.peerChannel_) {
        [self.peerChannel_ close];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)respond:(SPLKConnectionResponseAttachment *)data requestType:(uint32_t)requestType tag:(uint32_t)tag {
    [self _sendData:data frameOfType:requestType tag:tag];
}

- (void)pushData:(NSObject *)data type:(uint32_t)type {
    [self _sendData:data frameOfType:type tag:0];
}

- (void)_sendData:(NSObject *)data frameOfType:(uint32_t)frameOfType tag:(uint32_t)tag {
    if (self.peerChannel_) {
        NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:data];
        dispatch_data_t payload = [archivedData createReferencingDispatchData];
        
        [self.peerChannel_ sendFrameOfType:frameOfType tag:tag withPayload:payload callback:^(NSError *error) {
            if (error) {
            }
        }];
    }
}

#pragma mark - SPLK_PTChannelDelegate

- (BOOL)ioFrameChannel:(SPLK_PTChannel*)channel shouldAcceptFrameOfType:(uint32_t)type tag:(uint32_t)tag payloadSize:(uint32_t)payloadSize {
    if (channel != self.peerChannel_) {
        return NO;
    } else if ([self.requestHandler canHandleRequestType:type]) {
        return YES;
    } else {
        [channel close];
        return NO;
    }
}

- (void)ioFrameChannel:(SPLK_PTChannel*)channel didReceiveFrameOfType:(uint32_t)type tag:(uint32_t)tag payload:(SPLK_PTData*)payload {
    id object = nil;
    if (payload) {
        id unarchivedObject = [NSKeyedUnarchiver unarchiveObjectWithData:[NSData dataWithContentsOfDispatchData:payload.dispatchData]];
        if ([unarchivedObject isKindOfClass:[SPLKConnectionAttachment class]]) {
            SPLKConnectionAttachment *attachment = (SPLKConnectionAttachment *)unarchivedObject;
            object = attachment.data;
        } else {
            object = unarchivedObject;
        }
    }
    [self.requestHandler handleRequestType:type tag:tag object:object];
}

/// 当 Client 端链接成功时，该方法会被调用，然后 channel 的状态会变成 connected
- (void)ioFrameChannel:(SPLK_PTChannel*)channel didAcceptConnection:(SPLK_PTChannel*)otherChannel fromAddress:(SPLK_PTAddress*)address {
    NSLog(@"SPLKServer - channel:%@, acceptConnection:%@", channel.debugTag, otherChannel.debugTag);

    SPLK_PTChannel *previousChannel = self.peerChannel_;
    
    otherChannel.targetPort = address.port;
    self.peerChannel_ = otherChannel;
    
    [previousChannel cancel];
}

/// 当连接过 Lookin 客户端，然后 Lookin 客户端又被关闭时，会走到这里
- (void)ioFrameChannel:(SPLK_PTChannel*)channel didEndWithError:(NSError*)error {
    if (self.peerChannel_ != channel) {
        // Client 端第一次连接上时，之前 listen 的 port 会被 Peertalk 内部 cancel（并在 didAcceptConnection 方法里给业务抛一个新建的 connected 状态的 channel），那个被 cancel 的 channel 会走到这里
        NSLog(@"SPLKServer - Ignore channel%@ end.", channel.debugTag);
        return;
    }
    // Client 端关闭时，会走到这里
    NSLog(@"SPLKServer - channel%@ DidEndWithError:%@", channel.debugTag, error);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SPLKConnectionDidEndNotificationName object:self];
    [self searchPortToListenIfNoConnection];
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
