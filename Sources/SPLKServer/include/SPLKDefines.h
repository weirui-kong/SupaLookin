//
//  SPLKMessageProtocol.h
//  Lookin
//
//  Created by Li Kai on 2018/8/6.
//  https://lookin.work
//

#import "TargetConditionals.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#elif TARGET_OS_MAC
#import <Appkit/Appkit.h>
#endif

#include <stdint.h>

#pragma mark - Version

/// current release version of SPLKServer
static NSString * const SPLK_SERVER_READABLE_VERSION = @"1.0.14";

// The version of .supalookin documents, kept in SPLKHierarchyFile.serverVersion; connections use SPLKProtocol's generation.
static const int SPLK_DOCUMENT_VERSION = 1;

#pragma mark - Connection

/// SPLKServer 在真机上会依次尝试监听 47275 ~ 47279 这几个端口
static const int SPLKUSBDeviceIPv4PortNumberStart = 47275;
static const int SPLKUSBDeviceIPv4PortNumberEnd = 47279;

/// SPLKServer 在模拟器中会依次尝试监听 47264 ~ 47269 这几个端口
static const int SPLKSimulatorIPv4PortNumberStart = 47264;
static const int SPLKSimulatorIPv4PortNumberEnd = 47269;

static NSString * const SPLKStringFlag_VoidReturn = @"SPLK_TAG_RETURN_VALUE_VOID";

#pragma mark - Error

static NSString * const SPLKErrorDomain = @"SPLKError";

enum {
    SPLKErrCode_Default = -400,
    /// Lookin 内部业务逻辑错误
    SPLKErrCode_Inner = -401,
    /// PeerTalk 内部错误
    SPLKErrCode_PeerTalk = -402,
    /// 连接不存在或已断开
    SPLKErrCode_NoConnect = -403,
    /// ping 失败了，原因是 ping 请求超时
    SPLKErrCode_PingFailForTimeout = -404,
    /// 请求超时未返回
    SPLKErrCode_Timeout = -405,
    /// 有相同 Type 的新请求被发出，因此旧请求被丢弃
    SPLKErrCode_Discard = -406,
    /// ping 失败了，原因是 app 主动报告自身正处于后台模式
    SPLKErrCode_PingFailForBackgroundState = -407,
    
    /// 没有找到对应的对象，可能已被释放
    SPLKErrCode_ObjectNotFound = -500,
    /// 不支持修改当前类型的 SPLKCodingValueType
    SPLKErrCode_ModifyValueTypeInvalid = -501,
    SPLKErrCode_Exception = -502,
    
    // SPLKServer 版本过高，要升级 client
    SPLKErrCode_ServerVersionTooHigh = -600,
    // SPLKServer 版本过低，要升级 server
    SPLKErrCode_ServerVersionTooLow = -601,
    
    // 不支持的文件类型
    SPLKErrCode_UnsupportedFileType = -700,
};

#define SPLKErr_ObjNotFound [NSError errorWithDomain:SPLKErrorDomain code:SPLKErrCode_ObjectNotFound userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Failed to get target object in iOS app", nil), NSLocalizedRecoverySuggestionErrorKey:NSLocalizedString(@"Perhaps the related object was deallocated. You can reload Lookin to get newest data.", nil)}]

#define SPLKErr_NoConnect [NSError errorWithDomain:SPLKErrorDomain code:SPLKErrCode_NoConnect userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"The operation failed due to disconnection with the iOS app.", nil)}]

#define SPLKErr_Inner [NSError errorWithDomain:SPLKErrorDomain code:SPLKErrCode_Inner userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"The operation failed due to an inner error.", nil)}]

#define SPLKErrorMake(errorTitle, errorDetail) [NSError errorWithDomain:SPLKErrorDomain code:SPLKErrCode_Default userInfo:@{NSLocalizedDescriptionKey:errorTitle, NSLocalizedRecoverySuggestionErrorKey:errorDetail}]

#define SPLKErrorText_Timeout NSLocalizedString(@"Perhaps your iOS app is paused with breakpoint in Xcode, blocked by other tasks in main thread, or moved to background state.", nil)

#pragma mark - Colors

#if TARGET_OS_IPHONE
#define SPLKColor UIColor
#define SPLKInsets UIEdgeInsets
#define SPLKImage UIImage
#elif TARGET_OS_MAC
#define SPLKColor NSColor
#define SPLKInsets NSEdgeInsets
#define SPLKImage NSImage
#endif

#define SPLKColorRGBAMake(r, g, b, a) [SPLKColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a]
#define SPLKColorMake(r, g, b) [SPLKColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1]

#pragma mark - Preview

/// SCNNode 所允许的图片的最大的长和宽，单位是 px，这个值是 Scenekit 自身指定的
/// Max pixel size of a SCNNode object. It is designated by SceneKit.
static const double SPLKNodeImageMaxLengthInPx = 16384;

typedef NS_OPTIONS(NSUInteger, SPLKPreviewBitMask) {
    SPLKPreviewBitMask_None = 0,
    
    SPLKPreviewBitMask_Selectable = 1 << 1,
    SPLKPreviewBitMask_Unselectable = 1 << 2,
    
    SPLKPreviewBitMask_HasLight = 1 << 3,
    SPLKPreviewBitMask_NoLight = 1 << 4
};
