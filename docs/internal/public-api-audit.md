# Public API Audit

Living document tracking every public symbol in the SDK. Update this whenever a public symbol is added, removed, or changed.

**Status legend:**
- **PUBLIC** — intentional, stable public API
- **DISCUSS** — questionable; needs a decision
- **REMOVE** — marked for removal in a future version

---

## Entry points

| Symbol | Status | Notes |
|---|---|---|
| `Payrails` (class) | PUBLIC | Main namespace; all static factory methods live here |
| `Payrails.createSession(with:) async throws` | PUBLIC | Primary async session creation |
| `Payrails.createSession(with:onInit:)` | PUBLIC | Callback variant for non-async contexts |
| `Payrails.query(_:)` | PUBLIC | Read-only session state access |
| `Payrails.update(_:)` | PUBLIC | Runtime session state mutation (amount only) |
| `Payrails.getStoredInstruments()` | PUBLIC | Convenience accessor; returns all card + PayPal |
| `Payrails.getStoredInstruments(for:)` | PUBLIC | Type-filtered accessor |
| `Payrails.log(_:separator:terminator:file:function:line:)` | DISCUSS | Currently public — merchants could call this, but it's mainly internal. Consider making internal. |

> **Removed in 1.28.0:** `Payrails.api(_:_:_:)` has been removed. Use typed session methods (`session.deleteInstrument(instrumentId:)` and `session.updateInstrument(instrumentId:body:)`) instead.

---

## Session

| Symbol | Status | Notes |
|---|---|---|
| `Payrails.Session` (class) | PUBLIC | Returned from `createSession`; merchants rarely call methods directly |
| `Payrails.Session.isPaymentInProgress` | PUBLIC | Useful for disabling UI during payment |
| `Payrails.Session.isApplePayAvailable` | PUBLIC | Used to conditionally show Apple Pay button; combines config + device capability check |
| `Payrails.Session.isPaymentAvailable(type:)` | INTERNAL | Redundant with `query(.paymentMethodConfig)`; kept internal |
| `Payrails.Session.isPaymentCodeAvailable(paymentMethodCode:)` | INTERNAL | Redundant with `query(.paymentMethodConfig(.specific(code)))`; kept internal (matches Android SDK) |
| `Payrails.Session.storedInstruments(for:)` | PUBLIC | Prefer `Payrails.getStoredInstruments(for:)` |
| `Payrails.Session.executePayment(with:...:onResult:)` | PUBLIC | Direct session payment execution |
| `Payrails.Session.executePayment(withStoredInstrument:...:onResult:)` | PUBLIC | Stored instrument payment |
| `Payrails.Session.executePayment(with:...) async` | PUBLIC | Async variant |
| `Payrails.Session.cancelPayment()` | PUBLIC | Cancel in-flight payment |
| `Payrails.Session.tokenize(encryptedData:options:)` | PUBLIC | Card vaulting without payment |
| `Payrails.Session.deleteInstrument(instrumentId:)` | PUBLIC | Direct instrument deletion |
| `Payrails.Session.updateInstrument(instrumentId:body:)` | PUBLIC | Direct instrument update |
| `Payrails.Session.update(_:)` | PUBLIC | Runtime session state mutation |
| `Payrails.Session.query(_:)` | PUBLIC | Session-scoped query (prefer static `Payrails.query(_:)`) |
| `Payrails.Session.executionId` | DISCUSS | Currently `internal` (correct). Was previously accessible — do not re-expose; use `Payrails.query(.executionId)` instead. |

---

## Configuration

| Symbol | Status | Notes |
|---|---|---|
| `Payrails.InitData` | PUBLIC | |
| `Payrails.InitData.version` | PUBLIC | |
| `Payrails.InitData.data` | PUBLIC | |
| `Payrails.Configuration` | PUBLIC | |
| `Payrails.Options` | PUBLIC | |
| `Payrails.Env` | PUBLIC | `.production`, `.test` |

---

## Payment types

| Symbol | Status | Notes |
|---|---|---|
| `Payrails.PaymentType` | PUBLIC | `.card`, `.applePay`, `.payPal`, `.genericRedirect` |

---

## Query API

| Symbol | Status | Notes |
|---|---|---|
| `PayrailsQueryKey` | PUBLIC | |
| `PayrailsQueryKey.executionId` | PUBLIC | |
| `PayrailsQueryKey.holderReference` | PUBLIC | |
| `PayrailsQueryKey.amount` | PUBLIC | |
| `PayrailsQueryKey.binLookup` | PUBLIC | |
| `PayrailsQueryKey.instrumentDelete` | PUBLIC | |
| `PayrailsQueryKey.instrumentUpdate` | PUBLIC | |
| `PayrailsQueryKey.paymentMethodConfig` | PUBLIC | |
| `PayrailsQueryKey.paymentMethodInstruments` | PUBLIC | |
| `PayrailsQueryResult` | PUBLIC | |
| `PaymentMethodFilter` | PUBLIC | `.all`, `.redirect`, `.specific(String)` |
| `PayrailsAmount` | PUBLIC | Value + currency strings |
| `PayrailsLink` | PUBLIC | Method + href |
| `PayrailsPaymentOption` | PUBLIC | |
| `PayrailsPaymentOption.ClientConfig` | PUBLIC | |

---

## Updating session state

| Symbol | Status | Notes |
|---|---|---|
| `UpdateOptions` | PUBLIC | |
| `UpdateOptions.amount` | PUBLIC | Only mutable field currently |

---

## Callbacks and results

| Symbol | Status | Notes |
|---|---|---|
| `OnInitCallback` | PUBLIC | typealias |
| `OnPayCallback` | PUBLIC | typealias |
| `OnPayResult` | PUBLIC | `.success`, `.authorizationFailed`, `.failure`, `.error`, `.cancelledByUser` |

---

## Card form and payment button

| Symbol | Status | Notes |
|---|---|---|
| `Payrails.CardForm` | PUBLIC | UIStackView subclass |
| `Payrails.CardPaymentButton` | PUBLIC | Dual-mode (card form / stored instrument) |
| `Payrails.CardPaymentButton.delegate` | PUBLIC | |
| `Payrails.CardPaymentButton.presenter` | PUBLIC | |
| `Payrails.CardPaymentButton.pay(with:storedInstrument:)` | PUBLIC | Programmatic pay trigger |
| `Payrails.CardPaymentButton.setStoredInstrument(_:)` | PUBLIC | Switch to stored instrument mode |
| `Payrails.CardPaymentButton.clearStoredInstrument()` | PUBLIC | Revert to card form mode |
| `Payrails.CardPaymentButton.getStoredInstrument()` | PUBLIC | Read current stored instrument |
| `PayrailsCardPaymentButtonDelegate` | PUBLIC | |
| `PayrailsCardFormDelegate` | PUBLIC | |

---

## Card form configuration and styling

| Symbol | Status | Notes |
|---|---|---|
| `CardFormConfig` | PUBLIC | |
| `CardFormConfig.defaultConfig` | PUBLIC | |
| `CardFormStylesConfig` | PUBLIC | |
| `CardFormStylesConfig.defaultConfig` | PUBLIC | |
| `CardFormStylesConfig.effectiveInputStyles(for:)` | DISCUSS | Utility method; may not be needed publicly |
| `CardFieldSpecificStyles` | PUBLIC | |
| `CardFieldSpecificStyles.defaultStyle` | PUBLIC | |
| `CardFormStyle` | DISCUSS | Older style type, largely superseded by `CardFormStylesConfig`. Consider deprecating. |
| `CardButtonStyle` | PUBLIC | |
| `CardButtonStyle.defaultStyle` | PUBLIC | |
| `CardWrapperStyle` | PUBLIC | |
| `CardWrapperStyle.defaultStyle` | PUBLIC | |
| `FieldVariant` | PUBLIC | `.outlined`, `.filled` |
| `CardIconAlignment` | PUBLIC | `.left`, `.right` |
| `CardLayoutConfig` | PUBLIC | |
| `CardLayoutConfig.standard` | PUBLIC | |
| `CardLayoutConfig.compact` | PUBLIC | |
| `CardLayoutConfig.minimal` | PUBLIC | |
| `CardLayoutConfig.preset(_:useCombinedExpiryDateField:)` | PUBLIC | |
| `CardLayoutConfig.custom(_:useCombinedExpiryDateField:)` | PUBLIC | |
| `CardTranslations` | PUBLIC | |
| `CardTranslations.Placeholders` | PUBLIC | |
| `CardTranslations.Labels` | PUBLIC | |
| `CardTranslations.ErrorMessages` | PUBLIC | |
| `CardPaymenButtonTranslations` | PUBLIC | Note: typo in name (`Paymen`). DISCUSS whether to fix (breaking rename). |
| `CardStyle` (typealias for `Style`) | PUBLIC | |
| `Style.fieldInsets` | PUBLIC (via `public init`) | Field-to-container spacing. `internal` stored property, but settable via `public init(... fieldInsets:)`. Defaults to `nil` → `(0, 6, 0, 6)`. |
| `UIEdgeInsets.fieldInsets(top:left:bottom:right:)` | PUBLIC | Convenience factory with default values `(0, 6, 0, 6)`. Defined in `UIEdgeInsets+FieldInsets.swift`. |
| `CardFieldType` (typealias for `ElementType`) | PUBLIC | |

---

## Apple Pay

| Symbol | Status | Notes |
|---|---|---|
| `ApplePayElement` (protocol or class) | PUBLIC | Returned by `createApplePayButton` |
| `Payrails.ApplePayButton` | PUBLIC | |
| `Payrails.ApplePayButtonWithToggle` | PUBLIC | |
| `PayrailsApplePayButtonDelegate` | PUBLIC | |

---

## PayPal

| Symbol | Status | Notes |
|---|---|---|
| `PaypalElement` (protocol or class) | PUBLIC | Returned by `createPayPalButton` |
| `Payrails.PayPalButton` | PUBLIC | |
| `Payrails.PayPalButtonWithToggle` | PUBLIC | |
| `PayrailsPayPalButtonDelegate` | PUBLIC | |
| `StoredPayPalInstrument` | DISCUSS | Concrete type — should be accessed via `StoredInstrument` protocol |

---

## Generic redirect

| Symbol | Status | Notes |
|---|---|---|
| `Payrails.GenericRedirectButton` | PUBLIC | |
| `GenericRedirectPaymentButtonDelegate` | PUBLIC | |

---

## Stored instruments

| Symbol | Status | Notes |
|---|---|---|
| `StoredInstrument` (protocol) | PUBLIC | |
| `Payrails.StoredInstruments` | PUBLIC | |
| `Payrails.StoredInstruments.delegate` | PUBLIC | |
| `Payrails.StoredInstruments.presenter` | PUBLIC | |
| `Payrails.StoredInstruments.refreshInstruments()` | PUBLIC | |
| `Payrails.StoredInstruments.bindCardPaymentButton(_:)` | PUBLIC | |
| `Payrails.StoredInstrumentView` | PUBLIC | |
| `PayrailsStoredInstrumentsDelegate` | PUBLIC | |
| `PayrailsStoredInstrumentViewDelegate` | PUBLIC | |
| `PayrailsStoredInstrumentPaymentButtonDelegate` | PUBLIC | |
| `StoredInstrumentsStyle` | PUBLIC | |
| `StoredInstrumentButtonStyle` | PUBLIC | |
| `StoredInstrumentsTranslations` | PUBLIC | |
| `StoredInstrumentButtonTranslations` | PUBLIC | |
| `DeleteButtonStyle` | PUBLIC | |
| `UpdateButtonStyle` | PUBLIC | |

---

## Instrument responses

| Symbol | Status | Notes |
|---|---|---|
| `DeleteInstrumentResponse` | PUBLIC | |
| `UpdateInstrumentResponse` | PUBLIC | |
| `SaveInstrumentResponse` | PUBLIC | |
| `UpdateInstrumentBody` | PUBLIC | |
| `InstrumentAPIResponse` | PUBLIC | `.delete`, `.update` |

---

## Tokenization

| Symbol | Status | Notes |
|---|---|---|
| `TokenizeOptions` | PUBLIC | |
| `FutureUsage` | PUBLIC | `.cardOnFile`, `.subscription`, `.unscheduledCardOnFile` |

---

## Presenter protocol

| Symbol | Status | Notes |
|---|---|---|
| `PaymentPresenter` | PUBLIC | |
| `PaymentPresenter.presentPayment(_:)` | PUBLIC | |
| `PaymentPresenter.encryptedCardData` | DISCUSS | Leaks internal card data flow detail into the public protocol; review whether this needs to be public |

---

## Debug

| Symbol | Status | Notes |
|---|---|---|
| `Payrails.Debug` | PUBLIC | |
| `Payrails.Debug.configViewer()` | PUBLIC | SwiftUI view |
| `DebugManager` | DISCUSS | Currently public; likely only useful internally |
| `LogStore` | DISCUSS | Currently public; consider making internal |
| `LogLevel` | DISCUSS | Currently public; consider making internal |

---

## Vault / Skyflow layer

| Symbol | Status | Notes |
|---|---|---|
| `Client` | DISCUSS | Skyflow vault client — should not be part of the public API surface. Consider making internal. |
| `ComposableContainer` | DISCUSS | Same as above |
| `Container<T>` | DISCUSS | Same as above |
| `ContainerType` | DISCUSS | Same as above |
| `ContainerOptions` | DISCUSS | Same as above |
| `SkyflowElement` | DISCUSS | Same as above |
| `TextField` | DISCUSS | Same as above |
| `ElementType` | PUBLIC | Used as `CardFieldType`; required for config API |
| `EventName` | DISCUSS | Not needed in public API |
| `Style` | PUBLIC | Used as `CardStyle`; required for styling API |
| `Styles` | DISCUSS | Internal Skyflow styling — accessed via `CardStyle` / `CardFieldSpecificStyles` |
| `CollectElementInput` | DISCUSS | Internal vault config |
| `CollectElementOptions` | DISCUSS | Internal vault config |
| `Callback` | DISCUSS | Skyflow callback protocol — should be internal |
| `BaseElement` | DISCUSS | Protocol — may not need to be public |
| Validators (`ElementValueMatchRule`, `LengthMatchRule`, etc.) | DISCUSS | Used internally for card validation; review public necessity |

---

## Open issues

1. **`CardFormStyle` vs `CardFormStylesConfig`** — two overlapping style APIs. `CardFormStylesConfig` is the current standard. `CardFormStyle` is legacy. A deprecation path is needed.
2. **`Payrails.api(_:_:_:)` string dispatch** — removed in 1.28.0 in favour of the typed `session.deleteInstrument(instrumentId:)` and `session.updateInstrument(instrumentId:body:)` methods.
3. **`CardPaymenButtonTranslations` typo** — "Paymen" should be "Payment". Fix requires a breaking rename. Schedule for next major version.
4. **Vault types in public namespace** — `Client`, `Container`, `TextField`, etc. are Skyflow internals that accidentally surfaced as public. Audit and make internal.
5. **`PaymentPresenter.encryptedCardData`** — this property is an implementation detail of the 3DS flow. Review whether it needs to remain public.
