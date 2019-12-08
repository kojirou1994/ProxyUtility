// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "ProxyUtility",
    platforms: [
        .macOS(.v10_13)
    ],
    products: [
        .library(name: "ShadowsocksProtocol", targets: ["ShadowsocksProtocol"]),
        .library(name: "ProxyUtility", targets: ["ProxyUtility"]),
        .library(name: "ProxySubscription", targets: ["ProxySubscription"]),
        .library(name: "ClashSupport", targets: ["ClashSupport"]),
        .library(name: "ProxyRule", targets: ["ProxyRule"])
    ],
    dependencies: [
        .package(url: "https://github.com/kojirou1994/MaxMindDB.git", from: "1.0.3"),
        .package(url: "https://github.com/kojirou1994/Kwift.git", from: "0.3.1"),
        .package(url: "https://github.com/kojirou1994/URLFileManager.git", from: "0.0.1"),
    ],
    targets: [
        .target(
            name: "ProxyProtocol",
            dependencies: []),
        .target(
            name: "ShadowsocksProtocol",
            dependencies: [
                "KwiftExtension",
                "ProxyProtocol",
            ]
        ),
        .target(
            name: "V2RayProtocol",
            dependencies: [
                "ProxyProtocol"
            ]
        ),
        .target(
            name: "ProxyUtility",
            dependencies: [
                "ShadowsocksProtocol",
                "V2RayProtocol",
                "Executable",
                "MaxMindDB"
            ]
        ),
        .target(
            name: "ClashSupport",
            dependencies: [
                "ProxyUtility"
            ]
        ),
        .target(
            name: "SurgeSupport",
            dependencies: [
                "ProxyProtocol",
                "ShadowsocksProtocol"
            ]
        ),
        .target(
            name: "ProxySubscription",
            dependencies: [
                "ProxyUtility",
                "SurgeSupport",
                "URLFileManager"
            ]
        ),
        .target(
            name: "LocalTransporter",
            dependencies: [
                "ProxyUtility",
                "URLFileManager"
            ]
        ),
        .target(
            name: "ProxyRule",
            dependencies: [
            ]
        ),
        .testTarget(
            name: "ProxyUtilityTests",
            dependencies: ["ProxyUtility", "ProxySubscription", "ProxyRule"]),
    ]
)
