// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "PayrailsCheckout",
    products: [
        .library(
            name: "PayrailsCheckout",
            targets: ["PayrailsCheckout"]
        ),
    ],
    dependencies: [
        // Existing dependency on PayPal Checkout SDK
        .package(url: "https://github.com/paypal/paypalcheckout-ios", from: "1.0.0"),
        // New dependency on ios-cse (PayrailsCSE)
        .package(url: "https://github.com/payrails/ios-cse.git", from: "1.0.0"),
        .package(name: "PayrailsVault", path: "../PayrailsVault")
    ],
    targets: [
        .target(
            name: "PayrailsCheckout",
            dependencies: [
                // Reference the product "PayrailsCSE" from the package identified as "ios-cse"
                .product(name: "PayrailsCSE", package: "ios-cse"),
                // Reference the product from paypalcheckout-ios
                .product(name: "PayPalCheckout", package: "paypalcheckout-ios")
            ],
            path: "Payrails"
        ),
    ]
)
