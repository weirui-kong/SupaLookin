> 🚧 **Under active development. Things may break or change without notice.**

# SupaLookin

SupaLookin is based on [Lookin](https://github.com/hughkli/Lookin) and [LookinServer](https://github.com/QMUI/LookinServer). It ships its own iOS-side library, SPLKServer, and does not work with stock LookinServer.

## Integrating SPLKServer

SPLKServer ships as `SPLKServer.xcframework.zip` with every [release](https://github.com/weirui-kong/SupaLookin/releases/latest), prebuilt for iOS and the iOS Simulator.

- Add `SPLKServer.xcframework` to your app target with **Embed & Sign**. Or, with Swift Package Manager, use it as a `binaryTarget`; the release notes give its URL and checksum.
- Nothing imports it: it starts itself when the app launches.
- Keep it out of your Release builds: it runs in any build it's in.
- Requires iOS 15 or later.
- SPLKServer listens on ports 47264–47269 (simulator) and 47275–47279 (USB device). It doesn't clash with stock LookinServer, so both can run in the same app.
- The hooks your app can implement are LookinServer's with the `splk_` prefix: `splk_customDebugInfos`, `splk_collapsedClassList`, `splk_colorAlias`, `splk_shouldCaptureImage`, and so on.

Apps that added this repository as a Swift package should switch to the framework. The package is no longer meant for apps, and its newer versions run in Release builds too.

## Documentation

- [MCP server](Docs/MCP.md): let AI agents read the UI of the iOS app you are inspecting.

## License

- The macOS app is licensed under GPLv3 ([LICENSE](LICENSE)).
- SPLKServer (everything under [`Sources/`](Sources)) is derived from LookinServer and licensed under MIT ([Sources/LICENSE](Sources/LICENSE)).
