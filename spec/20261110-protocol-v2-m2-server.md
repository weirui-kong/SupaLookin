# Protocol v2 M2: server

## Summary

M2 moves SPLKServer from protocol v1 to v2. It adds:
- the shared converters (`SPLKModelBridge`);
- the server runtime (`SPLKServerSession`);
- a reusable end-to-end harness.

It removes v1's server transport. M2 ships in one release with M3 (`20261110-protocol-v2-m3-mac.md`), since v1 and v2 can't talk to each other.

## Package

New targets:

| Target | Language | Platforms | Depends on | Compiled when |
|---|---|---|---|---|
| `SPLKModelBridge` | Swift | macOS, iOS-family | `SPLKProtocol`, `SPLKServer` | `SHOULD_COMPILE_SPLK_SHARED` |
| `SPLKServerSession` | Swift | iOS-family | `SPLKProtocol`, `SPLKModelBridge`, `SPLKServer` | `SHOULD_COMPILE_SPLK_SERVER` |
| `SPLKEndToEndTests` | Swift Testing | macOS | `SPLKProtocol` | runs only with `SPLK_E2E=1` |

**Compile gates**: `SPLKProtocol` and `SPLKModelBridge` take the `SHOULD_COMPILE_SPLK_SHARED` gate. Every Swift file in them is wrapped in `#if SHOULD_COMPILE_SPLK_SHARED`, so iOS Release builds get empty modules, as the Objective-C targets already do.
- `Scripts/generate-protocol.sh` wraps the generated file the same way.
- The gate is set through `swiftSettings` with the same platform and configuration conditions as the C macro.

**Products**:
- `SPLKServer` contains `SPLKServer`, `SPLKServerSession` and their dependencies. iOS apps add only this product.
- A second product, `SPLKModelBridge`, gives the macOS app the bridge and protocol for M3.

**swift-protobuf in Release builds**: SPM can't drop a package dependency by build configuration, so an iOS Release build still links swift-protobuf, even though nothing references it there. Dead stripping removes what isn't referenced. The size it adds to a Release build of the e2e demo is measured and recorded under Verification.

## Start-up

- `SPLKConnectionManager +load` is replaced by a small Objective-C class, `SPLKServerLoader`. Its `+load` only registers for `UIApplicationDidFinishLaunchingNotification`, which runs before the first `UIApplicationDidBecomeActiveNotification`.
- When that notification arrives, the loader:
  - installs the host app hooks, below;
  - finds the Swift entry point with `NSClassFromString(@"SPLKServerBootstrap")` and sends it `start`.
- No Swift code runs during `+load`.
- `SPLKServerBootstrap` is the `@objc(SPLKServerBootstrap)` class in `SPLKServerSession`.

**Host app hooks**: these move unchanged from `SPLKConnectionManager.m` into `SPLKServerLoader.m`:
- `SPLK_2D` and `SPLK_3D`, which show the "local inspection was removed" alert;
- `SPLK_Export`;
- `SPLK_RelationSearch`;
- `GetSPLKInfo`, answering under `splkServerVersion`;
- the `SPLK` marker class.

## Listening

`SPLKServerSession` keeps v1's listening behavior:
- **On `didBecomeActive`**, when not already listening, it binds the first free port:
  - 47264–47269 on the simulator and for iOS apps on a Mac;
  - 47275–47279 on a device.

  It then serves an `SPLKHost`.
- **On `willResignActive`**, with no session open, it stops listening.
- **While the app is inactive**, every request fails with `FAILED_PRECONDITION` / `app_in_background`. This is the v2 form of v1's ping reporting `appIsInBackground` before every request.

The host's capabilities in M2:
- `app`, `hierarchy`, `details`;
- `attr.modify`, `attr.custom`, `attr.groups`;
- `object`, `object.invoke`, `object.selectors`;
- `image`, `gesture.toggle`.

`ServerHello.app` is built on the main thread from `SPLKAppInfo` without images, plus `ScreenInfo` from the key window's screen.

## Operations

- `SPLKRequestHandler.{h,m}` becomes `SPLKServerOperations.{h,m}`: one Objective-C method per v1 request, with the same body.
  - It reports results through completion blocks instead of `SPLKConnectionManager`.
  - Method invocation stays in Objective-C, since it needs `NSInvocation`.
- `SPLKHierarchyDetailsHandler` and `SPLKInbuiltAttrModificationHandler` keep their APIs.
- The v1 transport is deleted:
  - `SPLKConnectionManager.{h,m}`;
  - the server's use of `SPLK_PTChannel`;
  - the imports of `SPLKConnectionManager.h` in `CALayer+SPLKServer.m` and `SPLKHierarchyDetailsHandler.m`, which never use it.

**`SPLKServerSession`'s request handler**:
- runs each operation on the main actor;
- converts arguments from v2 with `SPLKModelBridge`;
- converts results back off the main actor, PNG encoding included.

| Method | Operation | Result |
|---|---|---|
| `GetAppInfo` | `SPLKAppInfo currentInfoWithScreenshot:icon:localIdentifiers:` | `AppInfo` |
| `GetHierarchy` | `SPLKHierarchyInfo staticInfoWithSPLKVersion:` with `ClientHello.client_version` | `HierarchySnapshot`, `version` counting up per session |
| `FetchDetails` | `SPLKHierarchyDetailsHandler startWithPackages:block:finishedBlock:` | one `NodeDetail` stream item per detail. Cancelling the call calls `cancel`. |
| `ModifyAttribute` | `SPLKInbuiltAttrModificationHandler handleModification:completion:` | `NodeDetail` |
| `FetchModificationPatch` | `SPLKInbuiltAttrModificationHandler handlePatchWithTasks:block:` | one `NodeDetail` per task |
| `ModifyCustomAttribute` | `SPLKCustomAttrModificationHandler handleModification:` | `Empty`, or `INTERNAL` when it returns `NO` |
| `InvokeMethod` | `SPLKServerOperations` | `InvokeResult` |
| `GetObject` | `SPLKServerOperations` | `ObjectRef` |
| `GetImageViewImage` | `SPLKServerOperations` | `EncodedImage` (PNG) |
| `SetGestureRecognizerEnabled` | `SPLKServerOperations` | `gesture_enabled` |
| `GetAttributeGroups` | `SPLKServerOperations` | `AttributeGroupList` |
| `ListSelectors` | `SPLKServerOperations` | `selectors` |

**Errors**: Objective-C errors in `SPLKErrorDomain` become statuses:

| v1 code | Status | Reason |
|---|---|---|
| `SPLKErrCode_ObjectNotFound` | `NOT_FOUND` | `object_deallocated` |
| `SPLKErrCode_ModifyValueTypeInvalid` | `INVALID_ARGUMENT` | `value_type_invalid` |
| `SPLKErrCode_Exception` | `INTERNAL` | `exception` |
| `SPLKErrCode_Inner` | `INTERNAL` | `inner` |
| any other | `INTERNAL` | `error` |

`title` and `detail` carry the error's `NSLocalizedDescriptionKey` and `NSLocalizedRecoverySuggestionErrorKey`, so messages such as "doesn't have an instance method called …" reach the Mac unchanged.

## Converters

`SPLKModelBridge` converts both ways between the `SPLK*` models and v2 messages. M3 uses the other direction.

| Objective-C | v2 |
|---|---|
| `SPLKAppInfo` | `AppSummary` and `AppInfo`. The screenshot and icon are PNG. |
| `SPLKHierarchyInfo` | `HierarchySnapshot`. `displayItems` is flattened in pre-order with `depth`. |
| `SPLKDisplayItem` | `Node`. Screenshots never travel in a `Node`; they arrive in `NodeDetail`. |
| `SPLKDisplayItemDetail` | `NodeDetail`. `frameValue`, `boundsValue`, `hiddenValue`, `alphaValue`, `customDisplayTitle` and `danceUISource` keep "unset" distinct from a value. `subitems` is flattened with `children_set`. |
| `SPLKObject`, `SPLKIvarTrace` | `ObjectRef`, `IvarTrace` |
| `SPLKEventHandler` | `EventHandler` |
| `SPLKCustomDisplayItemInfo` | `CustomNodeInfo` |
| `SPLKAttributesGroup`, `SPLKAttributesSection`, `SPLKAttribute` | `AttributeGroup`, `AttributeSection`, `Attribute`. `extraValue` becomes `enum_cases`. |
| `SPLKAutoLayoutConstraint` | `Constraint` |
| `SPLKStaticAsyncUpdateTask(sPackage)` | `DetailTask(Package)`. `clientReadableVersion` comes from `ClientHello.client_version`. |
| `SPLKAttributeModification`, `SPLKCustomAttrModification` | `ModifyAttribute`, `ModifyCustomAttribute`. Selectors travel as their names. |

Images are PNG on the wire, as v1's `splk_data` encoded them.

### Attribute values

Values convert by `SPLKAttrType`, plus the attribute identifier for `CustomObj`:

| `SPLKAttrType` | Objective-C value | `Value` case |
|---|---|---|
| `Char`, `Int`, `Short`, `Long`, `LongLong`, `EnumInt`, `EnumLong` | `NSNumber` | `int_value` |
| `UnsignedChar`, `UnsignedInt`, `UnsignedShort`, `UnsignedLong`, `UnsignedLongLong` | `NSNumber` | `uint_value` |
| `Float`, `Double` | `NSNumber` | `double_value` |
| `BOOL` | `NSNumber` | `bool_value` |
| `Sel`, `Class`, `NSString`, `EnumString`, `Json` | `NSString` | `string_value` |
| `CGPoint` | `NSValue` | `point` |
| `CGVector` | `NSValue` | `point` (dx, dy) |
| `UIOffset` | `NSValue` | `point` (horizontal, vertical) |
| `CGSize` | `NSValue` | `size` |
| `CGRect` | `NSValue` | `rect` |
| `CGAffineTransform` | `NSValue` | `transform` |
| `UIEdgeInsets` | `NSValue` | `insets` |
| `UIColor` | RGBA `NSArray<NSNumber>` | `color` |
| `Shadow` | `@{color: RGBA, offset: NSValue(CGSize), opacity, radius}` | `shadow` |
| `CustomObj`, `SPLKAttr_Class_Class_Class` | `NSArray<NSArray<NSString>>` | `list` of `list` of `string_value` |
| `CustomObj`, `SPLKAttr_Relation_Relation_Relation` | `NSArray<NSString>` | `list` of `string_value` |
| `CustomObj`, `SPLKAttr_AutoLayout_Constraints_Constraints` | `NSArray<SPLKAutoLayoutConstraint>` | `list` of `constraint` |
| `CustomObj`, `SPLKAttr_UIVisualEffectView_Style_Style` | `NSNumber` | `int_value` |
| `CustomObj`, `SPLKAttr_UIImageView_Open_Open` | `NSNumber` (an oid) | `uint_value` |
| `CustomObj`, `SPLKAttr_UITableView_RowsNumber_Number` | `NSArray<NSNumber>` | `list` of `int_value` |
| `None`, `Void` | `nil` | unset |

- Any `nil` value of another type travels as `null_value`.
- A value that doesn't match its row (a wrong class, an unknown `CustomObj` identifier) is a bug: the converter asserts in Debug and sends `null_value`. Adding an attribute with a new shape means adding a row here, and a `Value` case if none fits.

## End-to-end harness

`Scripts/e2e/` holds a demo app's sources: one Swift file and an `Info.plist`, using the scene life cycle. It isn't an Xcode project.
- **The demo's UI** has a fixed view tree that exercises every method:
  - a label, a text field and a text view;
  - an image view with an image;
  - a two-section table view;
  - a button with a target-action;
  - a view with a tap recognizer and Auto Layout constraints;
  - a visual effect view;
  - an object that implements `splk_customDebugInfos` with every custom attribute type.
- **`Scripts/e2e-sim.sh`**:
  1. builds the package's Debug objects for the iOS Simulator with `xcodebuild`;
  2. links the demo with `swiftc`;
  3. installs and launches it on a booted simulator, booting one if none is;
  4. waits for port 47264 to listen;
  5. runs `SPLK_E2E=1 swift test --filter SPLKEndToEndTests`.
- **`SPLKEndToEndTests`** connect an `SPLKClientSession` to `127.0.0.1:47264` and call every method against the demo's known tree, checking:
  - the results;
  - errors such as `NOT_FOUND` for a stale oid;
  - background rejection, after the script sends the demo home with `simctl`.

This reverses `20261109-splk-server.md`'s "A demo iOS app in this repository" being out of scope. An update note is appended there.

## Verification

- `SPLKModelBridge` tests, on macOS:
  - every row of the attribute value table;
  - every model, round-tripped Objective-C → v2 → Objective-C;
  - a 2,000-deep hierarchy flattened and rebuilt.
- `SPLKEndToEndTests` pass through `Scripts/e2e-sim.sh`.
- The package builds for the iOS Simulator in Debug and Release. The Release build has no `SPLK` Objective-C classes and no `SPLKV2` Swift types.
- The size swift-protobuf adds to a Release build of the demo is recorded here.

## Out of scope

- The Mac side (M3), leases and events (M4).
- `Subscribe`, `InjectInput`, `PerformAction` and `WaitForIdle`, which the host answers `UNIMPLEMENTED` since it doesn't list their capabilities.

## Update: implementation notes

- **Client version for v1's builders.** The hierarchy, details and modification builders enable custom info only for a v1 client version of at least 1.0.4, parsed by `splk_numbericOSVersion`, which asserts on anything but `x.y.z`.
  - Every v2 client supports custom info, so `SPLKServerSession` always passes `1.0.4` where v1 passed `clientVersion` or `clientReadableVersion`.
  - A peer's version string never reaches that parser.
  - `SPLKRequestContext` still carries `ClientHello.client_version`, for future use.
- **Custom attributes come with details**, as in v1. `GetHierarchy` nodes carry none; `FetchDetails` with `ATTR_NEED` does, including their `custom_setter_id`.
- **Deep `SPLK*` graphs.** The converter rebuilds a flattened tree top-down, since `setSubitems:` refreshes the subtree it attaches. The bridge test uses 300 levels instead of 2,000: releasing a deeper Objective-C graph recurses past a test task's stack. The app holds and releases these models on the main thread, as v1 did.
- **Release size.** Release builds have no `SPLK` Objective-C classes and no `SPLKV2` types. Measured on the e2e demo (iOS Simulator, `-O`, dead-stripped, symbols stripped):

  | Build | Size |
  |---|---|
  | demo alone | 92,904 bytes |
  | demo with SPLKServer, Release | 1,840,376 bytes |
  | demo with SPLKServer, Release, without `SwiftProtobuf.o` | 92,904 bytes |

  The increase, about 1.7 MB, is all swift-protobuf. Its Swift metadata and conformance records survive dead stripping even though nothing references them.
