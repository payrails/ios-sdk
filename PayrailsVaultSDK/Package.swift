// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "PayrailsVaultSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "PayrailsVaultSDK",
            targets: ["PayrailsVaultSDK"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PayrailsVaultSDK",
            dependencies: []),
        .testTarget(
            name: "PayrailsVaultSDKTests",
            dependencies: ["PayrailsVaultSDK"]),
    ]
)
