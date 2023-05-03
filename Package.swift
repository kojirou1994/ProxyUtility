// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "ProxyUtility",
  platforms: [
    .macOS(.v13),
  ],
  products: [
    .library(name: "ShadowsocksProtocol", targets: ["ShadowsocksProtocol"]),
    .library(name: "ProxyUtility", targets: ["ProxyUtility"]),
    .library(name: "ProxySubscription", targets: ["ProxySubscription"]),
    .library(name: "ClashSupport", targets: ["ClashSupport"]),
    .library(name: "ProxyRule", targets: ["ProxyRule"]),
    .library(name: "ProxyWorldUtility", targets: ["ProxyWorldUtility"]),
    .library(name: "QuantumultSupport", targets: ["QuantumultSupport"]),
    .executable(name: "proxyworld-cli", targets: ["proxyworld-cli"]),
  ],
  dependencies: [
    .package(url: "https://github.com/kojirou1994/MaxMindDB.git", from: "1.0.3"),
    .package(url: "https://github.com/kojirou1994/Kwift.git", from: "1.0.0"),
    .package(url: "https://github.com/kojirou1994/Precondition.git", from: "1.0.0"),
    .package(url: "https://github.com/kojirou1994/ProxyInfo.git", from: "0.0.1"),
    .package(url: "https://github.com/kojirou1994/URLFileManager.git", from: "0.0.3"),
    .package(url: "https://github.com/kojirou1994/Executable.git", from: "0.5.0"),
    .package(url: "https://github.com/kojirou1994/SystemUp.git", branch: "main"),
    .package(url: "https://github.com/jpsim/Yams.git", from: "3.0.0"),
    .package(url: "https://github.com/swift-extras/swift-extras-base64.git", from: "0.7.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "ProxyProtocol",
      dependencies: [
        .product(name: "ExtrasBase64", package: "swift-extras-base64"),
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
        "MaxMindDB",
        "ProxyInfo",
        "ClashSupport",
      ]
    ),
    .target(
      name: "ClashSupport",
      dependencies: [
        "ShadowsocksProtocol",
      ]
    ),
    .target(
      name: "QuantumultSupport",
      dependencies: [
        "ClashSupport"
      ]
    ),
    .target(
      name: "ProxySubscription",
      dependencies: [
        "ProxyUtility",
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
    .target(
      name: "ProxyWorldUtility",
      dependencies: [
        "ProxyRule",
        "ClashSupport",
        "ProxySubscription",
        .product(name: "SystemUp", package: "SystemUp"),
      ]
    ),
    .executableTarget(
      name: "generate-rule",
      dependencies: [
        "ProxyRule",
        "Yams",
        .product(name: "KwiftExtension", package: "Kwift"),
      ]
    ),
    .executableTarget(
      name: "proxyworld-cli",
      dependencies: [
        "ProxyWorldUtility",
        "QuantumultSupport",
        .product(name: "Precondition", package: "Precondition"),
        .product(name: "SystemUp", package: "SystemUp"),
        .product(name: "SystemFileManager", package: "SystemUp"),
        .product(name: "TSCExecutableLauncher", package: "Executable"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .testTarget(
      name: "ProxyUtilityTests",
      dependencies: ["ProxyUtility", "ProxySubscription", "ProxyRule", "ProxyWorldUtility"]),
  ]
)
