# Swift Package Manager Package Resolution Fix

## Issue Summary

**Reported by:** Blacklane (Nikita Mokhan)  
**Issue:** Package resolution fails when adding the Payrails iOS SDK as a dependency via Swift Package Manager

## Problem Description

When developers attempted to add the Payrails iOS SDK to their projects using Swift Package Manager with the repository URL `https://github.com/payrails/ios-sdk`, the package resolution would fail. This prevented customers from integrating the SDK into their iOS applications using Swift Package Manager, blocking their development and integration efforts.

## Root Cause Analysis

After investigating the issue, we identified two critical missing configurations in the `Package.swift` manifest:

### 1. Missing Platform Requirements

The Package.swift file did not specify any platform requirements, despite:
- The Payrails.podspec requiring iOS 14.0+ 
- The ios-cse dependency (PayrailsCSE) requiring iOS 14.0+
- The paypalcheckout-ios dependency requiring iOS 13.0+

Without explicit platform declarations, Swift Package Manager couldn't properly resolve the package and its dependencies.

### 2. Missing Resource Declarations

The package contains asset catalog files (`.xcassets`) that were not declared in the manifest:
- `Payrails/Classes/Public/Assets/Media.xcassets`
- `Payrails/Classes/Public/Media.xcassets`

These unhandled files caused warnings and contributed to resolution failures.

## Solution

### Changes Made to Package.swift

1. **Added Platform Requirements**
   ```swift
   platforms: [
       .iOS(.v14)
   ]
   ```
   This declares iOS 14.0 as the minimum supported version, matching:
   - The CocoaPods podspec configuration
   - The ios-cse dependency requirement
   - Apple's current platform recommendations

2. **Added Resource Declarations**
   ```swift
   resources: [
       .process("Classes/Public/Assets/Media.xcassets"),
       .process("Classes/Public/Media.xcassets")
   ]
   ```
   This properly declares the asset catalogs as processed resources, ensuring they're included in the package and handled correctly by Swift Package Manager.

### Complete Updated Package.swift Structure

```swift
// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "PayrailsCheckout",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "PayrailsCheckout",
            targets: ["PayrailsCheckout"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/paypal/paypalcheckout-ios", from: "1.0.0"),
        .package(url: "https://github.com/payrails/ios-cse.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "PayrailsCheckout",
            dependencies: [
                .product(name: "PayrailsCSE", package: "ios-cse"),
                .product(name: "PayPalCheckout", package: "paypalcheckout-ios")
            ],
            path: "Payrails",
            resources: [
                .process("Classes/Public/Assets/Media.xcassets"),
                .process("Classes/Public/Media.xcassets")
            ]
        ),
    ]
)
```

## Verification

The fix was verified by:

1. **Package Manifest Validation**
   ```bash
   swift package dump-package
   ```
   Confirmed that platforms and resources are correctly declared in the manifest.

2. **Package Resolution**
   ```bash
   swift package resolve
   ```
   Successfully resolved all dependencies:
   - PayPalCheckout 1.1.0
   - PayrailsCSE 1.0.0
   - JOSESwift 2.4.0 (transitive dependency)

3. **No Unhandled Files Warnings**
   The previous warnings about unhandled .xcassets files are now resolved.

## Impact

This fix enables developers to:

- ✅ Add the Payrails iOS SDK via Swift Package Manager without errors
- ✅ Use the standard SPM integration workflow: File → Add Package Dependencies → `https://github.com/payrails/ios-sdk`
- ✅ Have assets properly bundled with the package
- ✅ Meet the iOS 14.0+ platform requirement explicitly

## Customer Impact - Blacklane

This fix unblocks Blacklane's iOS integration, allowing them to:
- Start their iOS SDK integration immediately
- Meet their December go-live timeline
- Use their preferred dependency management tool (Swift Package Manager)

## Recommendations

### For SDK Users

1. **Add the Package**
   - In Xcode: File → Add Package Dependencies
   - Enter URL: `https://github.com/payrails/ios-sdk`
   - Select version: 1.0.0 or later

2. **Minimum Requirements**
   - iOS 14.0+
   - Swift 5.8+
   - Xcode 14.0+

### For SDK Maintainers

1. **CocoaPods Support**
   - The existing Payrails.podspec continues to work as before
   - Both Swift Package Manager and CocoaPods are now fully supported

2. **Future Considerations**
   - Keep Package.swift and Payrails.podspec platform versions in sync
   - Document both integration methods in README
   - Consider adding automated tests for both package managers

3. **Testing Package Updates**
   - Always test package resolution after making changes:
     ```bash
     swift package reset
     swift package resolve
     ```

## Related Files

- **Modified:** `Package.swift`
- **Related:** `Payrails.podspec` (unchanged, for reference)
- **Related:** `README.md` (already documents SPM installation)

## Timeline

- **Reported:** November 3, 2025
- **Priority:** High (customer blocker for December go-live)
- **Fixed:** November 12, 2025
- **Status:** Resolved

## Additional Notes

- This fix does not affect CocoaPods integration, which continues to work as before
- The SDK can now be used with both Swift Package Manager and CocoaPods
- No breaking changes to the SDK API or functionality
- The fix is backward compatible with existing integrations
