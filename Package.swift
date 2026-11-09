// swift-tools-version:5.9

import PackageDescription

let serverPlatforms: [Platform] = [.iOS, .tvOS, .visionOS, .macCatalyst]

let sharedDefines: [CSetting] = [
    .define("SHOULD_COMPILE_SPLK_SHARED", to: "1", .when(platforms: [.macOS])),
    .define("SHOULD_COMPILE_SPLK_SHARED", to: "1", .when(platforms: serverPlatforms, configuration: .debug)),
    .define("SHOULD_COMPILE_SPLK_SERVER", to: "1", .when(platforms: serverPlatforms, configuration: .debug)),
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
        .library(name: "SPLKServer", targets: ["SPLKServer"]),
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
    ]
)
