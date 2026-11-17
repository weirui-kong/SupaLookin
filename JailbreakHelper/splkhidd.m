//
//  splkhidd.m
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/18.
//

#import <CoreFoundation/CoreFoundation.h>
#import <arpa/inet.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#import <fcntl.h>
#import <mach/mach_time.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <notify.h>
#import <signal.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <sys/socket.h>
#import <sys/stat.h>
#import <time.h>
#import <unistd.h>

// Dispatches Supa Lookin's touches and buttons into a jailbroken device's HID event system, so they reach
// everything a finger does. The wire protocol is in spec/20261118-protocol-v2-m12-jailbreak-input.md.

typedef void *IOHIDEventRef;
typedef void *IOHIDEventSystemClientRef;
typedef void *IOHIDServiceClientRef;

static IOHIDEventSystemClientRef (*SPLKClientCreateWithType)(CFAllocatorRef, int, CFDictionaryRef);
static CFArrayRef (*SPLKClientCopyServices)(IOHIDEventSystemClientRef);
static void (*SPLKClientDispatchEvent)(IOHIDEventSystemClientRef, IOHIDEventRef);
static CFTypeRef (*SPLKServiceCopyProperty)(IOHIDServiceClientRef, CFStringRef);
static CFTypeRef (*SPLKServiceGetRegistryID)(IOHIDServiceClientRef);
static IOHIDEventRef (*SPLKCreateDigitizerEvent)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, double, double, double, double, double, Boolean, Boolean, uint32_t);
static IOHIDEventRef (*SPLKCreateFingerEvent)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, double, double, double, double, double, Boolean, Boolean, uint32_t);
static IOHIDEventRef (*SPLKCreateKeyboardEvent)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, Boolean, uint32_t);
static void (*SPLKAppendEvent)(IOHIDEventRef, IOHIDEventRef, uint32_t);
static void (*SPLKSetIntegerValue)(IOHIDEventRef, uint32_t, int);
static void (*SPLKSetSenderID)(IOHIDEventRef, uint64_t);

static const int SPLKClientTypeAdministrative = 0;
static const uint32_t SPLKTransducerHand = 3;
static const uint32_t SPLKMaskRange = 1;
static const uint32_t SPLKMaskTouch = 2;
static const uint32_t SPLKMaskPosition = 4;
static const uint32_t SPLKFieldDigitizerIsDisplayIntegrated = (11 << 16) | 25;
static const uint16_t SPLKPort = 47290;
static const int64_t SPLKIdleExitSeconds = 30;
static const time_t SPLKTokenMaxAge = 60;
static const char *SPLKTokenPath = "/var/mobile/Media/SupaLookin/splkhid-token";
#define SPLKMaxFingers 10
// Hardware services carry IORegistry entry IDs; virtual ones (accessibility, druid) carry larger, pointer-like IDs.
static const uint64_t SPLKHardwareRegistryIDLimit = 1ULL << 33;

static IOHIDEventSystemClientRef sClient;
static uint64_t sTouchscreenSender;
static uint64_t sButtonSender;
static int sFingerDown[SPLKMaxFingers];

static BOOL SPLKLoadSymbols(void) {
    void *iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
    if (!iokit) {
        return NO;
    }
    SPLKClientCreateWithType = dlsym(iokit, "IOHIDEventSystemClientCreateWithType");
    SPLKClientCopyServices = dlsym(iokit, "IOHIDEventSystemClientCopyServices");
    SPLKClientDispatchEvent = dlsym(iokit, "IOHIDEventSystemClientDispatchEvent");
    SPLKServiceCopyProperty = dlsym(iokit, "IOHIDServiceClientCopyProperty");
    SPLKServiceGetRegistryID = dlsym(iokit, "IOHIDServiceClientGetRegistryID");
    SPLKCreateDigitizerEvent = dlsym(iokit, "IOHIDEventCreateDigitizerEvent");
    SPLKCreateFingerEvent = dlsym(iokit, "IOHIDEventCreateDigitizerFingerEvent");
    SPLKCreateKeyboardEvent = dlsym(iokit, "IOHIDEventCreateKeyboardEvent");
    SPLKAppendEvent = dlsym(iokit, "IOHIDEventAppendEvent");
    SPLKSetIntegerValue = dlsym(iokit, "IOHIDEventSetIntegerValue");
    SPLKSetSenderID = dlsym(iokit, "IOHIDEventSetSenderID");
    return SPLKClientCreateWithType && SPLKClientCopyServices && SPLKClientDispatchEvent && SPLKServiceCopyProperty && SPLKServiceGetRegistryID
        && SPLKCreateDigitizerEvent && SPLKCreateFingerEvent && SPLKCreateKeyboardEvent && SPLKAppendEvent && SPLKSetIntegerValue && SPLKSetSenderID;
}

static int SPLKIntegerProperty(IOHIDServiceClientRef service, CFStringRef key) {
    int value = 0;
    CFTypeRef property = SPLKServiceCopyProperty(service, key);
    if (property) {
        if (CFGetTypeID(property) == CFNumberGetTypeID()) {
            CFNumberGetValue(property, kCFNumberIntType, &value);
        }
        CFRelease(property);
    }
    return value;
}

// The lowest hardware registry ID among services of the usage, or 0.
static uint64_t SPLKFindSender(CFArrayRef services, int usagePage, int usage) {
    uint64_t found = 0;
    for (CFIndex i = 0; i < CFArrayGetCount(services); i++) {
        IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
        if (SPLKIntegerProperty(service, CFSTR("PrimaryUsagePage")) != usagePage || SPLKIntegerProperty(service, CFSTR("PrimaryUsage")) != usage) {
            continue;
        }
        CFTypeRef registryID = SPLKServiceGetRegistryID(service);
        uint64_t value = 0;
        if (registryID && CFGetTypeID(registryID) == CFNumberGetTypeID()) {
            CFNumberGetValue(registryID, kCFNumberSInt64Type, &value);
        }
        if (value != 0 && value < SPLKHardwareRegistryIDLimit && (found == 0 || value < found)) {
            found = value;
        }
    }
    return found;
}

// NULL on success, else the reason the greeting reports.
static const char *SPLKFindSenders(void) {
    CFArrayRef services = SPLKClientCopyServices(sClient);
    if (!services) {
        return "no-services";
    }
    sTouchscreenSender = SPLKFindSender(services, 0x0D, 0x04);
    // The side button reports through Apple's vendor-page button service; SpringBoard ignores a Lock press from
    // consumer control. Devices without that service fall back to consumer control.
    sButtonSender = SPLKFindSender(services, 0xFF00, 0x04);
    if (!sButtonSender) {
        sButtonSender = SPLKFindSender(services, 0x0C, 0x01);
    }
    CFRelease(services);
    if (!sTouchscreenSender) {
        return "no-touchscreen";
    }
    if (!sButtonSender) {
        return "no-buttons";
    }
    return NULL;
}

// "T <id>:<x>:<y>:<down> ...", one finger per field.
static BOOL SPLKDispatchTouches(char *fields) {
    uint64_t now = mach_absolute_time();
    IOHIDEventRef fingers[SPLKMaxFingers];
    int count = 0;
    uint32_t handMask = 0;
    BOOL anyDown = NO;
    char *saveField = NULL;
    for (char *field = strtok_r(fields, " ", &saveField); field && count < SPLKMaxFingers; field = strtok_r(NULL, " ", &saveField)) {
        int identifier = 0, down = 0;
        double x = 0, y = 0;
        if (sscanf(field, "%d:%lf:%lf:%d", &identifier, &x, &y, &down) != 4 || identifier < 0 || identifier >= SPLKMaxFingers) {
            return NO;
        }
        // Touch and range change on touch-down and lift; a finger that stays down only moves.
        uint32_t mask = SPLKMaskPosition;
        if (down != sFingerDown[identifier]) {
            mask |= SPLKMaskTouch | SPLKMaskRange;
        }
        sFingerDown[identifier] = down;
        handMask |= mask;
        anyDown = anyDown || down;
        fingers[count++] = SPLKCreateFingerEvent(kCFAllocatorDefault, now, (uint32_t)identifier + 1, (uint32_t)identifier + 2, mask, x, y, 0, down ? 1 : 0, 0, down, down, 0);
    }
    if (count == 0) {
        return NO;
    }
    IOHIDEventRef hand = SPLKCreateDigitizerEvent(kCFAllocatorDefault, now, SPLKTransducerHand, 0, 0, handMask, 0, 0, 0, 0, 0, 0, anyDown, anyDown, 0);
    SPLKSetIntegerValue(hand, SPLKFieldDigitizerIsDisplayIntegrated, 1);
    for (int i = 0; i < count; i++) {
        SPLKAppendEvent(hand, fingers[i], 0);
        CFRelease(fingers[i]);
    }
    SPLKSetSenderID(hand, sTouchscreenSender);
    SPLKClientDispatchEvent(sClient, hand);
    CFRelease(hand);
    return YES;
}

// "B <page> <usage> <holdMs>", page and usage in hexadecimal.
static BOOL SPLKDispatchButton(const char *arguments) {
    unsigned int page = 0, usage = 0, holdMs = 0;
    if (sscanf(arguments, "%x %x %u", &page, &usage, &holdMs) != 3 || holdMs > 10000) {
        return NO;
    }
    for (int down = 1; down >= 0; down--) {
        IOHIDEventRef event = SPLKCreateKeyboardEvent(kCFAllocatorDefault, mach_absolute_time(), page, usage, down, 0);
        SPLKSetSenderID(event, sButtonSender);
        SPLKClientDispatchEvent(sClient, event);
        CFRelease(event);
        if (down) {
            usleep(holdMs * 1000);
        }
    }
    return YES;
}

static dispatch_queue_t sQueue;
static int sClientFD = -1;
static dispatch_source_t sClientSource;
static BOOL sGreeted;
static char sBuffer[8192];
static size_t sUsed;
static BOOL sLocked;
static void (*SPLKGetScreenLockStatus)(BOOL *locked, BOOL *passcodeEnabled);
static int (*SPLKGetDeviceLockState)(CFDictionaryRef options);
static uint64_t sIdleGeneration;

static void SPLKWriteLine(int fd, const char *line) {
    size_t length = strlen(line);
    while (length > 0) {
        ssize_t written = write(fd, line, length);
        if (written <= 0) {
            return;
        }
        line += written;
        length -= (size_t)written;
    }
}

// Lifts every finger still down, so a vanished client or a lock can't leave a touch stuck on the screen.
static void SPLKLiftAllFingers(void) {
    char line[256] = "";
    for (int i = 0; i < SPLKMaxFingers; i++) {
        if (sFingerDown[i]) {
            char field[32];
            snprintf(field, sizeof field, "%s%d:0:0:0", line[0] ? " " : "", i);
            strlcat(line, field, sizeof line);
        }
    }
    if (line[0]) {
        SPLKDispatchTouches(line);
    }
}

// SpringBoard's com.apple.springboard.lockstate is also nonzero while Notification Center is pulled down over an
// unlocked device, so it only says when to look again. SpringBoard's screen lock status is what locks the device.
static BOOL SPLKIsLocked(void) {
    if (SPLKGetScreenLockStatus) {
        BOOL locked = YES;
        BOOL passcodeEnabled = NO;
        SPLKGetScreenLockStatus(&locked, &passcodeEnabled);
        return locked;
    }
    // The keybag is 0 when unlocked and 3 when the device has no passcode.
    if (SPLKGetDeviceLockState) {
        int state = SPLKGetDeviceLockState(NULL);
        return state != 0 && state != 3;
    }
    return YES;
}

static void SPLKLoadLockSymbols(void) {
    void *springBoardServices = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);
    if (springBoardServices) {
        SPLKGetScreenLockStatus = dlsym(springBoardServices, "SBSGetScreenLockStatus");
    }
    void *keyBag = dlopen("/System/Library/PrivateFrameworks/MobileKeyBag.framework/MobileKeyBag", RTLD_NOW);
    if (keyBag) {
        SPLKGetDeviceLockState = dlsym(keyBag, "MKBGetDeviceLockState");
    }
}

// The token Supa Lookin wrote over AFC, which only a paired host can reach. Each token works once.
static BOOL SPLKAcceptToken(const char *token) {
    char expected[129] = "";
    struct stat info;
    BOOL fresh = stat(SPLKTokenPath, &info) == 0 && time(NULL) - info.st_mtime <= SPLKTokenMaxAge;
    int fd = open(SPLKTokenPath, O_RDONLY);
    if (fd >= 0) {
        ssize_t length = read(fd, expected, sizeof expected - 1);
        close(fd);
        expected[length > 0 ? length : 0] = '\0';
        expected[strcspn(expected, "\r\n")] = '\0';
    }
    unlink(SPLKTokenPath);
    size_t length = strlen(expected);
    if (!fresh || length < 32 || strlen(token) != length) {
        return NO;
    }
    unsigned char difference = 0;
    for (size_t i = 0; i < length; i++) {
        difference |= (unsigned char)(expected[i] ^ token[i]);
    }
    return difference == 0;
}

static void SPLKScheduleIdleExit(void) {
    uint64_t generation = ++sIdleGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, SPLKIdleExitSeconds * NSEC_PER_SEC), sQueue, ^{
        if (generation == sIdleGeneration && sClientFD < 0) {
            exit(0);
        }
    });
}

static void SPLKCloseClient(void) {
    if (sClientFD < 0) {
        return;
    }
    SPLKLiftAllFingers();
    dispatch_source_cancel(sClientSource);
    sClientSource = NULL;
    sClientFD = -1;
    sGreeted = NO;
    sUsed = 0;
    SPLKScheduleIdleExit();
}

// NO closes the connection.
static BOOL SPLKHandleLine(char *line) {
    if (!sGreeted) {
        if (strncmp(line, "HELLO 1 ", 8) != 0) {
            return NO;
        }
        const char *error = NULL;
        if (!SPLKAcceptToken(line + 8)) {
            error = "token";
        } else if (SPLKIsLocked()) {
            error = "locked";
        } else {
            error = SPLKFindSenders();
        }
        char reply[64];
        snprintf(reply, sizeof reply, error ? "SPLKHID 1 ERROR %s\n" : "SPLKHID 1 OK\n", error);
        SPLKWriteLine(sClientFD, reply);
        sGreeted = error == NULL;
        sLocked = NO;
        return sGreeted;
    }
    BOOL isTouch = strncmp(line, "T ", 2) == 0;
    BOOL isButton = strncmp(line, "B ", 2) == 0;
    if (!isTouch && !isButton) {
        return NO;
    }
    if (sLocked) {
        return YES;
    }
    return isTouch ? SPLKDispatchTouches(line + 2) : SPLKDispatchButton(line + 2);
}

static void SPLKReadClient(void) {
    ssize_t received = read(sClientFD, sBuffer + sUsed, sizeof sBuffer - sUsed - 1);
    if (received <= 0) {
        SPLKCloseClient();
        return;
    }
    sUsed += (size_t)received;
    sBuffer[sUsed] = '\0';
    char *start = sBuffer;
    char *newline;
    while ((newline = strchr(start, '\n'))) {
        *newline = '\0';
        if (!SPLKHandleLine(start)) {
            SPLKCloseClient();
            return;
        }
        start = newline + 1;
    }
    sUsed = (size_t)(sBuffer + sUsed - start);
    memmove(sBuffer, start, sUsed);
    if (sUsed >= sizeof sBuffer - 1) {
        SPLKCloseClient();
    }
}

// A new client replaces the old one: Supa Lookin keeps one connection per device session.
static void SPLKAcceptClient(int listener) {
    int fd = accept(listener, NULL, NULL);
    if (fd < 0) {
        return;
    }
    SPLKCloseClient();
    sIdleGeneration++;
    int noDelay = 1;
    setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &noDelay, sizeof noDelay);
    sClientFD = fd;
    sClientSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)fd, 0, sQueue);
    dispatch_source_set_event_handler(sClientSource, ^{
        SPLKReadClient();
    });
    dispatch_source_set_cancel_handler(sClientSource, ^{
        close(fd);
    });
    dispatch_resume(sClientSource);
}

static void SPLKLockStateDidChange(void) {
    BOOL locked = SPLKIsLocked();
    if (locked == sLocked) {
        return;
    }
    sLocked = locked;
    if (locked) {
        SPLKLiftAllFingers();
    }
    if (sClientFD >= 0 && sGreeted) {
        SPLKWriteLine(sClientFD, locked ? "STATE locked\n" : "STATE unlocked\n");
    }
}

// launchd's socket when launchd started us; otherwise, for development, our own.
static int SPLKListener(void) {
    int (*activate)(const char *, int **, size_t *) = dlsym(RTLD_DEFAULT, "launch_activate_socket");
    int *fds = NULL;
    size_t count = 0;
    if (activate && activate("Listeners", &fds, &count) == 0 && count > 0) {
        int fd = fds[0];
        free(fds);
        return fd;
    }
    int listener = socket(AF_INET, SOCK_STREAM, 0);
    int reuse = 1;
    setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof reuse);
    struct sockaddr_in address = {0};
    address.sin_family = AF_INET;
    address.sin_port = htons(SPLKPort);
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (bind(listener, (struct sockaddr *)&address, sizeof address) != 0 || listen(listener, 1) != 0) {
        perror("splkhidd: listen");
        close(listener);
        return -1;
    }
    return listener;
}

int main(void) {
    signal(SIGPIPE, SIG_IGN);
    if (!SPLKLoadSymbols()) {
        fprintf(stderr, "splkhidd: IOKit's HID functions are missing\n");
        return 1;
    }
    sClient = SPLKClientCreateWithType(kCFAllocatorDefault, SPLKClientTypeAdministrative, NULL);
    if (!sClient) {
        fprintf(stderr, "splkhidd: can't create a HID client\n");
        return 1;
    }
    int listener = SPLKListener();
    if (listener < 0) {
        return 1;
    }
    sQueue = dispatch_queue_create("org.supacode.app.lookin.splkhid", DISPATCH_QUEUE_SERIAL);
    SPLKLoadLockSymbols();
    // Unlocking with Face ID leaves the lock screen's lockstate alone until it's swiped away; the keybag says so first.
    const char *lockNotifications[] = {"com.apple.springboard.lockstate", "com.apple.springboard.hasBlankedScreen", "com.apple.mobile.keybagd.lock_status"};
    for (size_t i = 0; i < sizeof lockNotifications / sizeof *lockNotifications; i++) {
        int token;
        notify_register_dispatch(lockNotifications[i], &token, sQueue, ^(int token) {
            SPLKLockStateDidChange();
        });
    }
    dispatch_source_t acceptSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)listener, 0, sQueue);
    dispatch_source_set_event_handler(acceptSource, ^{
        SPLKAcceptClient(listener);
    });
    dispatch_resume(acceptSource);
    dispatch_async(sQueue, ^{
        SPLKScheduleIdleExit();
    });
    dispatch_main();
}
