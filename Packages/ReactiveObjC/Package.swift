// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "ReactiveObjC",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ReactiveObjC", targets: ["ReactiveObjC"])
    ],
    targets: [
        .target(
            name: "ReactiveObjC",
            cSettings: [
                .headerSearchPath("include/ReactiveObjC"),
                .headerSearchPath("PrivateHeaders"),
                .headerSearchPath("PrivateHeaders/ReactiveObjC")
            ]
        )
    ]
)
