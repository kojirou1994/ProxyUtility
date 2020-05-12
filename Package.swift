// swift-tools-version:5.2

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
        .package(url: "https://github.com/kojirou1994/Kwift.git", from: "0.5.0"),
        .package(url: "https://github.com/kojirou1994/URLFileManager.git", from: "0.0.3"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "3.0.0"),
        .package(url: "https://github.com/fabianfett/swift-base64-kit", from: "0.0.2")
    ],
    targets: [
        .target(
            name: "ProxyProtocol",
            dependencies: [
              .product(name: "Base64Kit", package: "swift-base64-kit"),
        ]),
        .target(
            name: "ShadowsocksProtocol",
            dependencies: [
              .product(name: "KwiftExtension", package: "Kwift"),
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
                "URLFileManager",
                "ClashSupport",
                "Yams"
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
