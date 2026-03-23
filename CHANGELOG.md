# Changelog

All notable changes to the Payrails iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.26.1] - 2026-03-23

### Changed
- `Payrails.Env` cases renamed: `.prod` → `.production` and `.dev` → `.test` for clearer environment naming (ONB-427)

> ⚠️ **Breaking change:** Update all references to `.prod` → `.production` and `.dev` → `.test` in your integration.

## [1.26.0] - 2026-03-23

### Added
- `Payrails.api(...)` is now public — merchants can call `deleteInstrument` and `updateInstrument` directly
- `onThreeDSecureChallenge` callback now fires on `PayrailsCardPaymentButtonDelegate` during 3DS flows
- Structured documentation: `docs/public/` (8 merchant-facing docs) and `docs/internal/` (7 contributor docs) following the Divio documentation system
- `/release-sdk` Claude skill for automated release preparation
- `CHANGELOG.md` following Keep a Changelog format

### Changed
- `Payrails.api(_:_:_:)` access level changed from `internal` to `public`, aligning with Android SDK pattern

### Fixed
- `CardPaymentButton` delegate now receives 3DS challenge notifications — previously the `onThreeDSecureChallenge` protocol method was declared but never invoked

## [1.25.3] - 2026-03-03

### Added
- `PayrailsQueryKey.paymentMethodConfig(PaymentMethodFilter)` with `.all`, `.redirect`, `.specific(String)` filter enum
- `PayrailsQueryKey.paymentMethodInstruments(type:)` for querying stored instruments by payment type

### Changed
- Use generic card icons and update base URL
- Consolidated `UpdateOptions.Amount` into `PayrailsAmount`
- Tightened `paymentMethodConfig` with `PaymentMethodFilter` enum

### Fixed
- PayPal `isDefault` decoding from server response
- Field focus correction
- SDK color guarding

## [1.25.2] - 2026-02-26

### Added
- Stored instrument binding via `StoredInstruments.bindCardPaymentButton(_:)`
- `CardPaymentButton` mode switching: `setStoredInstrument(_:)` / `clearStoredInstrument()`
- `onStoredInstrumentChanged(_:instrument:)` delegate callback
- `StoredInstrument.isDefault` property decoded from server response

### Changed
- Customization iterations and layout modifications
- Card icon and number enhancements

## [1.25.1] - 2026-02-13

### Added
- `CardForm.tokenize(options:)` for card vaulting without payment
- `TokenizeOptions` with `storeInstrument` and `futureUsage` configuration
- `SaveInstrumentResponse` with instrument metadata (ID, BIN, suffix, network, expiry, fingerprint)
- Exposed initialization data

### Changed
- Documentation updates
- Improved ISO8601 date decoding

## [1.2.0] - 2025-12-09

### Changed
- Removed hardcoded values from the SDK

### Added
- Generic redirect payment method support via `GenericRedirectButton`
- `Payrails.createGenericRedirectButton(buttonStyle:translations:paymentMethodCode:)`

## [1.1.3] - 2025-11-20

### Fixed
- SPM related compilation errors

## [1.1.2] - 2025-11-18

### Fixed
- Swift Package Manager issues

### Changed
- Documentation refinements

## [1.1.1] - 2025-06-20

### Changed
- Instrument updates

## [1.1.0] - 2025-06-06

### Added
- Apple Pay support
- Generic redirect buttons
- Saved instruments functionality

## [1.0.0] - 2025-04-30

### Added
- Initial release
- Secure fields and payment executor
- Customizable card forms
- PayPal integration
- CocoaPods and Swift Package Manager distribution
