> 🚧 **Under active development. Things may break or change without notice.**

# SupaLookin

SupaLookin is based on [Lookin](https://github.com/hughkli/Lookin) and [LookinServer](https://github.com/QMUI/LookinServer). It ships its own iOS-side library, SPLKServer, and does not work with stock LookinServer.

## Integrating SPLKServer

Add this repository as a Swift package and link the `SPLKServer` product to your iOS app target:

```swift
.package(url: "https://github.com/weirui-kong/SupaLookin", from: "1.0.16")
```

In Xcode: File › Add Package Dependencies…, enter `https://github.com/weirui-kong/SupaLookin`, and add `SPLKServer` to your app.

- SPLKServer only does anything in the Debug configuration. Its own modules are empty in Release builds, but SPM still links swift-protobuf there, about 1.7 MB.
- Building it needs Xcode 26 or later (Swift 6.2), which its swift-protobuf dependency requires.
- Requires iOS 13, tvOS 13 or visionOS 1 or later. Mac Catalyst is supported.
- SPLKServer listens on ports 47264–47269 (simulator) and 47275–47279 (USB device). It doesn't clash with stock LookinServer, so both can run in the same app.
- The hooks your app can implement are LookinServer's with the `splk_` prefix: `splk_customDebugInfos`, `splk_collapsedClassList`, `splk_colorAlias`, `splk_shouldCaptureImage`, and so on.

## Documentation

- [MCP server](Docs/MCP.md): let AI agents read the UI of the iOS app you are inspecting.

## License

- The macOS app is licensed under GPLv3 ([LICENSE](LICENSE)).
- SPLKServer (everything under [`Sources/`](Sources)) is derived from LookinServer and licensed under MIT ([Sources/LICENSE](Sources/LICENSE)).
