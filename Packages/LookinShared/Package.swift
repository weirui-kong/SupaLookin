// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "LookinShared",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "LookinShared", targets: ["LookinShared"])
    ],
    targets: [
        .target(
            name: "LookinShared",
            cSettings: [
                .define("SHOULD_COMPILE_LOOKIN_SERVER", to: "1"),
                // The sources rely on Cocoa being pre-imported, as CocoaPods' generated prefix header did.
                .unsafeFlags(["-include", "Cocoa/Cocoa.h"])
            ]
        )
    ]
)
