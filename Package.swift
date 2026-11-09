// swift-tools-version:6.2

import PackageDescription

let serverPlatforms: [Platform] = [.iOS, .tvOS, .visionOS, .macCatalyst]

let sharedDefines: [CSetting] = [
    .define("SHOULD_COMPILE_SPLK_SHARED", to: "1", .when(platforms: [.macOS])),
    .define("SHOULD_COMPILE_SPLK_SHARED", to: "1", .when(platforms: serverPlatforms, configuration: .debug)),
    .define("SHOULD_COMPILE_SPLK_SERVER", to: "1", .when(platforms: serverPlatforms, configuration: .debug)),
]

let sharedSwiftDefines: [SwiftSetting] = [
    .define("SHOULD_COMPILE_SPLK_SHARED", .when(platforms: [.macOS])),
    .define("SHOULD_COMPILE_SPLK_SHARED", .when(platforms: serverPlatforms, configuration: .debug)),
]

let serverSwiftDefines: [SwiftSetting] = [
    .define("SHOULD_COMPILE_SPLK_SERVER", .when(platforms: serverPlatforms, configuration: .debug)),
]

let package = Package(
    name: "SupaLookin",
    platforms: [
        .macOS(.v14),
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "SPLKServer", targets: ["SPLKServer", "SPLKServerSession"]),
        .library(name: "SPLKModelBridge", targets: ["SPLKModelBridge"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf", from: "1.39.0"),
    ],
    targets: [
        .target(
            name: "SPLKServerBase",
            path: "Sources/SPLKServerBase",
            cSettings: sharedDefines
        ),
        .target(
            name: "SPLKServerSwift",
            dependencies: ["SPLKServerBase"],
            path: "Sources/SPLKServerSwift",
            swiftSettings: [
                .define("SHOULD_COMPILE_SPLK_SERVER", .when(platforms: serverPlatforms, configuration: .debug)),
                .swiftLanguageMode(.v5),
            ]
        ),
        .target(
            name: "SPLKServer",
            dependencies: ["SPLKServerBase", "SPLKServerSwift"],
            path: "Sources/SPLKServer",
            cSettings: sharedDefines + [
                .headerSearchPath("Server/Category"),
                .headerSearchPath("Server/Connection"),
                .headerSearchPath("Server/Connection/RequestHandler"),
                .headerSearchPath("Server/Others"),
            ]
        ),
        .target(
            name: "SPLKProtocol",
            dependencies: [.product(name: "SwiftProtobuf", package: "swift-protobuf")],
            path: "Sources/SPLKProtocol",
            exclude: ["Schema"],
            swiftSettings: sharedSwiftDefines
        ),
        .target(
            name: "SPLKModelBridge",
            dependencies: ["SPLKProtocol", "SPLKServer"],
            path: "Sources/SPLKModelBridge",
            swiftSettings: sharedSwiftDefines
        ),
        .target(
            name: "SPLKServerSession",
            dependencies: ["SPLKProtocol", "SPLKModelBridge", "SPLKServer"],
            path: "Sources/SPLKServerSession",
            swiftSettings: serverSwiftDefines
        ),
        .testTarget(
            name: "SPLKProtocolTests",
            dependencies: ["SPLKProtocol"],
            path: "Tests/SPLKProtocolTests"
        ),
        .testTarget(
            name: "SPLKModelBridgeTests",
            dependencies: ["SPLKModelBridge"],
            path: "Tests/SPLKModelBridgeTests"
        ),
        .testTarget(
            name: "SPLKEndToEndTests",
            dependencies: ["SPLKProtocol", "SPLKServer"],
            path: "Tests/SPLKEndToEndTests"
        ),
    ]
)
