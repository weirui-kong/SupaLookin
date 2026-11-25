// swift-tools-version:6.2

import PackageDescription

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
        .library(name: "SPLKServerDynamic", type: .dynamic, targets: ["SPLKServer", "SPLKServerSession"]),
        .library(name: "SPLKModelBridge", targets: ["SPLKModelBridge"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf", from: "1.39.0"),
    ],
    targets: [
        .target(
            name: "SPLKServerBase",
            path: "Sources/SPLKServerBase"
        ),
        .target(
            name: "SPLKServerSwift",
            dependencies: ["SPLKServerBase"],
            path: "Sources/SPLKServerSwift",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "SPLKServer",
            dependencies: ["SPLKServerBase", "SPLKServerSwift"],
            path: "Sources/SPLKServer",
            cSettings: [
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
            exclude: ["Schema"]
        ),
        .target(
            name: "SPLKImageCodec",
            path: "Sources/SPLKImageCodec"
        ),
        .target(
            name: "SPLKModelBridge",
            dependencies: ["SPLKProtocol", "SPLKServer", "SPLKImageCodec"],
            path: "Sources/SPLKModelBridge"
        ),
        .target(
            name: "SPLKServerSession",
            dependencies: ["SPLKProtocol", "SPLKModelBridge", "SPLKServer"],
            path: "Sources/SPLKServerSession"
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
