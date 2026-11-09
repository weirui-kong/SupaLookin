//
//  SPLKServerOperations.h
//  SPLKServer
//
//  Created by Weirui Kong on 2026/11/10.
//

#import <Foundation/Foundation.h>

@class SPLKAppInfo, SPLKHierarchyInfo, SPLKStaticAsyncUpdateTasksPackage, SPLKStaticAsyncUpdateTask, SPLKDisplayItemDetail, SPLKAttributeModification, SPLKCustomAttrModification, SPLKObject, SPLKAttributesGroup;

NS_ASSUME_NONNULL_BEGIN

// v1's request bodies, answering through blocks. Implemented on iOS-family platforms in Debug only; call on the main thread.
@interface SPLKServerOperations : NSObject

+ (SPLKAppInfo *)appInfoWithImages:(BOOL)needImages localIdentifiers:(NSArray<NSNumber *> *)localIdentifiers;

+ (SPLKHierarchyInfo *)hierarchyWithClientVersion:(nullable NSString *)clientVersion;

// Returns a token for `cancelDetailsFetching:`.
+ (id)fetchDetailsWithPackages:(NSArray<SPLKStaticAsyncUpdateTasksPackage *> *)packages
                      progress:(void (^)(NSArray<SPLKDisplayItemDetail *> *details))progress
                      finished:(void (^)(void))finished NS_SWIFT_NAME(fetchDetails(packages:progress:finished:));

+ (void)cancelDetailsFetching:(id)fetching;

+ (void)modifyAttribute:(SPLKAttributeModification *)modification
                  reply:(void (^)(SPLKDisplayItemDetail * _Nullable detail, NSError * _Nullable error))reply NS_SWIFT_NAME(modifyAttribute(_:reply:));

// Calls `progress` once per task.
+ (void)fetchModificationPatchWithTasks:(NSArray<SPLKStaticAsyncUpdateTask *> *)tasks
                               progress:(void (^)(SPLKDisplayItemDetail *detail))progress NS_SWIFT_NAME(fetchModificationPatch(tasks:progress:));

+ (BOOL)modifyCustomAttribute:(SPLKCustomAttrModification *)modification;

+ (nullable SPLKObject *)objectWithOid:(unsigned long)oid;

// The live object behind an oid, or nil once it's gone.
+ (nullable id)liveObjectForOid:(unsigned long)oid;

+ (void)attributeGroupsForLayerOid:(unsigned long)oid
                             reply:(void (^)(NSArray<SPLKAttributesGroup *> * _Nullable groups, NSError * _Nullable error))reply NS_SWIFT_NAME(attributeGroups(layerOid:reply:));

+ (void)selectorNamesForClassName:(NSString *)className
                           hasArg:(BOOL)hasArg
                            reply:(void (^)(NSArray<NSString *> * _Nullable names, NSError * _Nullable error))reply NS_SWIFT_NAME(selectorNames(className:hasArg:reply:));

// The reply's dictionary holds "description" (an NSString) and, for object results, "object" (an SPLKObject).
+ (void)invokeMethodOnOid:(unsigned long)oid
                     text:(NSString *)text
                    reply:(void (^)(NSDictionary<NSString *, id> * _Nullable result, NSError * _Nullable error))reply NS_SWIFT_NAME(invokeMethod(oid:text:reply:));

+ (void)imageDataForImageViewOid:(unsigned long)oid
                           reply:(void (^)(NSData * _Nullable data, NSError * _Nullable error))reply NS_SWIFT_NAME(imageData(imageViewOid:reply:));

+ (void)setGestureRecognizerOid:(unsigned long)oid
                        enabled:(BOOL)enabled
                          reply:(void (^)(NSNumber * _Nullable enabled, NSError * _Nullable error))reply NS_SWIFT_NAME(setGestureRecognizer(oid:enabled:reply:));

@end

NS_ASSUME_NONNULL_END
