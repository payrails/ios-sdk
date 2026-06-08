# Changelog

All notable changes to the Payrails iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.0] - 2026-06-08

### Added
- Unified `Payrails.Session.tokenize(_:options:)` API for saving card and Apple Pay instruments without charging. `Payrails.TokenizationRequest` selects `.card(CardForm)` or `.applePay(presenter:)`, and both paths return `SaveInstrumentResponse`. (ONB-768)
- Callback-based tokenization with distinct `onSuccess`, `onFailed`, and `onCancelled` outcomes for integrations that do not use async/await. (ONB-768)

### Changed
- `CardForm.tokenize(options:)` now routes through the unified session tokenization path, keeping card and Apple Pay instrument creation on the same backend contract. (ONB-768)

### Fixed
- Empty required card fields now apply the configured invalid underline or border styling instead of falling back to the base style. (ONB-856)
- Card field style updates now write `requiredAstrisk` configuration to the correct style slot. (ONB-856)

### Documentation
- Added unified card and Apple Pay tokenization examples and updated the public API reference, concepts, architecture, and merchant usage guides. (ONB-768)

## [2.0.0] - 2026-06-02

### Added
- `AuthorizationFailure` struct — payload passed to `onAuthorizeFailed(_:failure:)` on every delegate protocol. Carries `code: AuthorizationFailureReason` (discriminator), `message: String` (backend detail or generic fallback — never nil), and `rawError: Error?` (the underlying error when one exists). Flat `{ code, message, rawError }` shape, matching the Web SDK's `onFailed` payload. (ONB-739)
- `AuthorizationFailureReason` enum — string-raw-valued discriminator on `AuthorizationFailure.code`. Four cases mirror the Web SDK 1:1: `.authorizationError` ("AUTHORIZATION_ERROR"), `.authenticationError` ("AUTHENTICATION_ERROR"), `.userCancelled` ("USER_CANCELLED"), `.unknownError` ("UNKNOWN_ERROR"). Web's `VALIDATION_FAILED` is intentionally absent — input validation runs client-side before submission. (ONB-739)
- `SessionExpiredHandler` closure type and a new `onSessionExpired:` parameter on `Payrails.createSession(...)` (both callback and `async` overloads). The merchant supplies a closure that fetches a fresh `InitData` from their backend; the SDK invokes it when it detects the current Payrails execution is no longer reusable and swaps its internal config in place — the merchant's cached `Session` reference and any buttons / forms keep working unchanged. (ONB-739, see ADR-001)
- `OnPayResult.pending` case for the backend-pending-execution path. Surfaced when the backend returns `pending` with `actionRequired: nil` (no 3DS, no redirect — execution still live and may settle later). Routed to merchants via `onAuthorizePending(_:)`. (ONB-739)
- Concurrent backend polling during 3DS — a background poll task now runs alongside the WebView so the SDK can resolve payments even when the WebView's redirect chain stalls. A single-shot `claimTerminal()` NSLock arbitrates between WebView URL signals and polling signals so exactly one path reports the outcome. (ONB-739)
- User-dismiss detection on the 3DS WebView via `UIAdaptivePresentationControllerDelegate.presentationControllerDidDismiss(_:)`. After a 3-attempt × 1s confirmation poll for a real backend terminal, an unresolved dismiss surfaces as `OnPayResult.authorizationFailed(.userCancelled)` and triggers the `onSessionExpired` refresh. (ONB-739)

### Changed
- **Breaking:** `onAuthorizeFailed(_:)` is now `onAuthorizeFailed(_:failure:)` on every delegate protocol (`PayrailsCardPaymentButtonDelegate`, `PayrailsCardPaymentFormDelegate`, `PayrailsStoredInstrumentPaymentButtonDelegate`, `GenericRedirectPaymentButtonDelegate`). The new `failure: AuthorizationFailure` parameter carries the discriminating code, the backend message, and the raw error. Merchants switch on `failure.code` and read `failure.message` / `failure.rawError`. (ONB-739)
- **Breaking:** `OnPayResult` collapsed to three cases: `.success`, `.authorizationFailed(AuthorizationFailure)`, `.pending`. The previous `.authorizationFailed`, `.failure`, `.error(_:)`, and `.cancelledByUser` cases are merged into `.authorizationFailed(_)` — the carried `AuthorizationFailure` discriminates via `.code`. User-cancel surfaces as `.authorizationFailed(.userCancelled)` (not a top-level case). Callers of `session.executePayment(..., onResult:)` must update their switch statements. (ONB-739)
- When the backend returns `pending(executionResult)`, the SDK now branches on `executionResult.actionRequired`: if nil, surface `OnPayResult.pending` to the caller immediately (no 3DS challenge presented); if present, perform the action and start the background poll as before. (ONB-739)
- Sessions left in `authorizePending` after the user abandons a 3DS challenge are now refreshed automatically by the SDK via the merchant's `onSessionExpired` closure. The merchant's `Session` reference and cached buttons / forms keep working — only the underlying execution changes. If no closure was supplied at `createSession`, the SDK logs a warning at init and the next payment attempt fails naturally against the dead execution. (ONB-739)

### Removed
- **Breaking:** `onSessionExpired(_:)` delegate method on `PayrailsCardPaymentButtonDelegate`, `PayrailsCardPaymentFormDelegate`, `PayrailsStoredInstrumentPaymentButtonDelegate`, and `GenericRedirectPaymentButtonDelegate` is gone. Session refresh moved from a per-button delegate callback to a Session-init closure (see Added). Merchants who implemented the delegate method should remove it and supply the closure to `createSession` instead. (ONB-739, see ADR-001 — driven by review feedback from @kumaraksi on PR #78)

> ⚠️ **Breaking change:** Existing merchants who conform to any of the four card/redirect delegate protocols must update their `onAuthorizeFailed` signature to take `failure: AuthorizationFailure` instead of no payload. See `docs/public/quick-start.md` for the new switch pattern.

### Fixed
- Apple Pay payments no longer fail silently after a successful authorization. The dismissal callback was treated as a user cancellation, which aborted the in-flight `makePayment`. `ApplePayHandler` now latches a `didAuthorize` flag and only emits `.canceled` when no authorization happened. (ONB-766)
- App no longer crashes with "continuation resumed more than once" after an Apple Pay payment. The `.canceled` branch in `Session.paymentHandlerDidFinish` now nils `onResult` and `paymentHandler`, matching the other terminal paths. (ONB-767)
- `ApplePayHandler.didAuthorizePayment` now emits `.error(nil)` when `payment.token.paymentData` fails to parse as JSON, instead of leaving the merchant's continuation hanging. (ONB-766)
- 3DS WebView no longer hangs indefinitely when the backend redirect chain stalls on `/redirect/wait/workflow/…` or lands on an unrecognized URL — the concurrent backend poll surfaces the real terminal status. (ONB-739)
- User dismissing the 3DS sheet (swipe-down) now fires `onAuthorizeFailed(_:failure:)` with `failure.code == .userCancelled` instead of leaving the merchant app in "Processing payment…" indefinitely. (ONB-739)
- Backend's `errors[0].reason.result` is now threaded through to `AuthorizationFailure.message` instead of being dropped. Merchants get actionable backend copy ("ParamsError", "Insufficient funds", etc.) on the failure callback. (ONB-739)
- Sessions left in `authorizePending` after a 3DS dismissal are now refreshed automatically by the SDK (via the `onSessionExpired` closure supplied at `createSession`). Previously, merchants had to detect this externally and rebuild the `Session` themselves, which was error-prone across cached button / form references. (ONB-739)
- The 3-second fixed `Task.sleep` previously used as the user-dismiss grace window has been replaced with a 3-attempt × 1s confirmation-poll loop, eliminating false user-cancel reports when the backend reaches a real terminal within the window. (ONB-739)

### Documentation
- `docs/public/sdk-api-reference.md` no longer publicly documents `OnPayResult`; the public surface is the `createSession(with:onSessionExpired:)` constructor plus the delegate API (`onAuthorizeSuccess`, `onAuthorizeFailed(_:failure:)`, `onAuthorizePending`). `AuthorizationFailure` and `AuthorizationFailureReason` are documented as the failure payload and discriminator. (ONB-739)
- ADR-001 captures the design rationale for moving from a per-button `onSessionExpired` delegate to the refresh-closure pattern. (ONB-739)

## [1.28.0] - 2026-04-22

### Added
- `Payrails.Session` methods are now public: `executePayment(...)` (all variants), `deleteInstrument(instrumentId:)`, `updateInstrument(instrumentId:body:)`, `query(_:)`, `isApplePayAvailable`, and `update(_:)`. Headless merchants can now drive the full payment lifecycle and instrument management from their own UI with compile-time safety. Session data reads (stored instruments, payment method config, amount, execution id, etc.) go through `session.query(_:)` as the single read accessor — matches the Android SDK convention. (ONB-521)
- `session.getPaymentMethodConfig(_:)` — typed getter returning `[PayrailsPaymentOption]` filtered by `.all`, `.redirect`, or `.specific(code)`. Mirrors the web SDK's `getPaymentMethodConfig(paymentMethod)` API. (ONB-521)

### Changed
- `Session.isApplePayAvailable` is now a pure device-capability check (`PKPaymentAuthorizationController.canMakePayments()`), matching the web SDK. It no longer inspects the session configuration. For the combined "configured and device capable" signal, compose: `session.isApplePayAvailable && !session.getPaymentMethodConfig(.specific("apple_pay")).isEmpty`. (ONB-521)

> ⚠️ **Behaviour change:** `isApplePayAvailable` now returns `true` on any Apple-Pay-capable device regardless of whether Apple Pay is configured for the session. Merchants previously relying on the property as a combined check must explicitly verify configuration via `getPaymentMethodConfig(.specific("apple_pay"))`.

### Removed
- `Payrails.api(_:_:_:)` and the `InstrumentAPIResponse` enum have been removed. Use the typed session methods `session.deleteInstrument(instrumentId:)` and `session.updateInstrument(instrumentId:body:)` instead. They return `DeleteInstrumentResponse` and `UpdateInstrumentResponse` directly, with compile-time safety against typos and internal renames. (ONB-521)
- Internal-only `Session.isPaymentAvailable(type:)` and `Session.isPaymentCodeAvailable(paymentMethodCode:)` have been deleted. Both were unreachable from merchant code (internal access, no external callers) and had zero internal callers. Use `session.getPaymentMethodConfig(.specific(code))` or `session.query(.paymentMethodConfig(...))` instead. (ONB-521)

> ⚠️ **Breaking change:** Callers of `Payrails.api("deleteInstrument", ...)` / `Payrails.api("updateInstrument", ...)` must migrate to the session methods. See the README for the new pattern.

### Fixed
- `ComposableContainer` no longer applies `fieldSpacing` (row spacing) above the first row or below the last row of the card form. The first row now pins flush to the parent top, and the parent bottom uses a small 5pt padding below the last error label instead of `rowSpacing`. Merchants previously compensating with negative `wrapperStyle.padding` insets can remove that workaround. (ONB-517)

## [1.27.0] - 2026-04-08

### Added
- `fieldInsets` property on `Style` struct for controlling field-to-container spacing (ONB-324)
- `UIEdgeInsets.fieldInsets(top:left:bottom:right:)` convenience factory with 6pt default (ONB-324)
- Per-field `fieldInsets` overrides via `inputFieldStyles` (ONB-324)
- Unit tests for `fieldInsets` property, convenience extension, and constraints (ONB-324)

### Changed
- `ComposableContainer` now uses `fieldInsets` for field-to-container spacing instead of hardcoded values (ONB-492)
- Centralised shared Semgrep rules and reusable CI workflow (PS-293)
- Replaced Trivy with Semgrep for security scanning (PS-281)

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
