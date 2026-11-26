// swift-tools-version: 5.8
// Manifest for the PUBLIC Payrails iOS distribution repo.
//
// Do not edit the three constants below by hand - scripts/release/publish-distribution.sh
// rewrites them on every release. Everything else is reviewed here, in the source repo.
import PackageDescription

let version = "3.4.0"
let checksum = "eee303822966123da71fe9410be5dff2d091e9b9c6ca81f20b60af1af438aba3"
let repository = "payrails/ios-sdk"

let package = Package(
    name: "Payrails",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "Payrails",
            targets: ["PayrailsTarget"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/paypal/paypalcheckout-ios", from: "1.0.0"),
        .package(url: "https://github.com/payrails/ios-cse.git", from: "2.0.1")
    ],
    targets: [
        .binaryTarget(
            name: "Payrails",
            url: "https://github.com/\(repository)/releases/download/\(version)/Payrails.xcframework.zip",
            checksum: checksum
        ),
        // SE-0272 gives .binaryTarget no `dependencies:` parameter, so this empty
        // source target carries them and links the binary. Merchants still write
        // `import Payrails` - that resolves to the binary's module, not this target.
        // Same shape as GoogleMobileAdsTarget and OneSignal's *Wrapper targets.
        .target(
            name: "PayrailsTarget",
            dependencies: [
                "Payrails",
                .product(name: "PayrailsCSE", package: "ios-cse"),
                .product(name: "PayPalCheckout", package: "paypalcheckout-ios")
            ],
            path: "Sources/PayrailsTarget"
        )
    ]
)
