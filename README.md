# Payrails iOS SDK

The Payrails Checkout SDK for iOS, distributed as a prebuilt, signed XCFramework.

## Installation

In Xcode, click **File → Add Package Dependencies** and enter the package URL:

```
https://github.com/payrails/ios-sdk.git
```

Select the `Payrails` product and add it to your app target. To declare the
dependency in a `Package.swift` instead:

```swift
dependencies: [
    .package(url: "https://github.com/payrails/ios-sdk.git", from: "3.0.0")
]
```

Swift Package Manager downloads the framework and verifies it against the checksum
in this repository's `Package.swift`. `PayrailsCSE` and `PayPalCheckout` resolve as
separate package dependencies and appear in your project alongside `Payrails`.

## Upgrading from 2.x

- The public API is identical. `import Payrails` and every public symbol resolve
  unchanged, so no integration code has to move.
- Re-resolve once. `Package.resolved` pins the revision resolved against the old
  source target, and 3.0.0 replaces that target with a binary one. Click
  **File → Packages → Reset Package Caches**, then resolve again.
- CocoaPods is no longer supported. The previously documented
  `pod 'Payrails/Checkout', '~> 2.1'` never resolved, because CocoaPods trunk only
  ever carried 1.0.0. Move to Swift Package Manager.

## Working with a binary SDK

- Stepping into SDK code and grepping its sources are not available. The public API
  is documented at [docs.payrails.com](https://docs.payrails.com).
- Crash reports need the SDK's debug symbols to name Payrails frames. Payrails
  builds `Payrails.dSYMs.zip` for every release; request the file for the version
  you shipped through a support ticket, then upload it to your crash reporter
  alongside your app's own dSYMs. Symbols only match the exact SDK version.
- Each release is built with Xcode 16.4. Swift's module interface format is not
  backward compatible across toolchains, so an older Xcode can fail to load the
  framework.

## Requirements

| Requirement | Value |
|---|---|
| iOS deployment target | 14.0+ |
| Swift version | 5.0+ |

## Documentation

See the [Payrails documentation](https://docs.payrails.com).

## Source

Releases are built and published automatically from a private source repository.
This repository holds the package manifest that points at them.

The Swift files still checked in here are the 2.x source tree, kept for reference.
They are frozen at [2.1.0](https://github.com/payrails/ios-sdk/tree/2.1.0), they are
not what 3.x ships, and Swift Package Manager does not read them - `Package.swift`
resolves the SDK from the release archive. The same goes for `Payrails.podspec`:
CocoaPods is not supported, as above.
