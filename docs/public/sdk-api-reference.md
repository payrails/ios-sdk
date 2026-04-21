# SDK API Reference

**Current version:** 1.27.0
**Minimum deployment target:** iOS 14.0
**Swift version:** 5.0+
**Distribution:** CocoaPods (`Payrails/Checkout`) · Swift Package Manager

---

## Installation

### CocoaPods

```ruby
pod 'Payrails/Checkout', '~> 1.26'
```

### Swift Package Manager

```
https://github.com/payrails/ios-sdk.git
```

---

## Getting started

### `Payrails.InitData`

Holds the init payload returned by your backend after calling the Payrails initialization endpoint.

```swift
public struct Payrails.InitData: Codable {
    public init(version: String, data: String)
    public let version: String  // Version string from backend response
    public let data: String     // Base64-encoded JSON payload from backend response
}
```

### `Payrails.Options`

Runtime options passed to `Configuration`.

```swift
public struct Payrails.Options {
    public init(env: Payrails.Env = .production)
    public let env: Payrails.Env
}

public enum Payrails.Env: String {
    case production
    case test
}
```

### `Payrails.Configuration`

Wraps `InitData` and `Options` as the input to `createSession`.

```swift
public struct Payrails.Configuration {
    public init(initData: Payrails.InitData, option: Payrails.Options)
    public let initData: Payrails.InitData
    public let option: Payrails.Options
}
```

### `Payrails.createSession(with:)`

Creates and stores a session. All factory methods use the most recently created session.

```swift
// Async/await
public static func createSession(
    with configuration: Payrails.Configuration
) async throws -> Payrails.Session

// Callback
public static func createSession(
    with configuration: Payrails.Configuration,
    onInit: OnInitCallback
)

public typealias OnInitCallback = (Result<Payrails.Session, PayrailsError>) -> Void
```

---

## Session

`Payrails.Session` is returned from `createSession` and is the single typed API surface for headless integrations. All session data reads go through `query(_:)` — there are no dedicated getters.

```swift
public class Payrails.Session {
    // Availability
    public var isApplePayAvailable: Bool { get }

    // Payment execution — callback variants
    public func executePayment(
        with type: PaymentType,
        paymentMethodCode: String?,
        saveInstrument: Bool,
        presenter: PaymentPresenter?,
        onResult: @escaping OnPayCallback
    )

    public func executePayment(
        withStoredInstrument instrument: StoredInstrument,
        presenter: PaymentPresenter?,
        onResult: @escaping OnPayCallback
    )

    // Payment execution — async variants
    @MainActor public func executePayment(
        with type: Payrails.PaymentType,
        paymentMethodCode: String?,
        saveInstrument: Bool,
        presenter: PaymentPresenter?
    ) async -> OnPayResult

    @MainActor public func executePayment(
        withStoredInstrument instrument: StoredInstrument,
        presenter: PaymentPresenter?
    ) async -> OnPayResult

    // Instrument management
    public func deleteInstrument(instrumentId: String) async throws -> DeleteInstrumentResponse
    public func updateInstrument(instrumentId: String, body: UpdateInstrumentBody) async throws -> UpdateInstrumentResponse

    // Session state
    public func query(_ key: PayrailsQueryKey) -> PayrailsQueryResult?
    public func update(_ options: UpdateOptions)
}
```

---

## Payment types

```swift
public enum Payrails.PaymentType: String {
    case card
    case applePay
    case payPal
    case genericRedirect
}
```

---

## Factory methods

All factory methods are static methods on `Payrails` and require an active session.

### Card form

```swift
public static func createCardForm(
    config: CardFormConfig? = nil,
    showSaveInstrument: Bool = false
) -> Payrails.CardForm
```

`Payrails.CardForm` is a `UIStackView` subclass. Add it to your view hierarchy and constrain with Auto Layout.

### Card payment button

```swift
// Card form mode — requires prior createCardForm()
public static func createCardPaymentButton(
    buttonStyle: CardButtonStyle? = nil,
    translations: CardPaymenButtonTranslations
) -> Payrails.CardPaymentButton

// Stored instrument mode
public static func createCardPaymentButton(
    storedInstrument: StoredInstrument,
    buttonStyle: StoredInstrumentButtonStyle? = nil,
    translations: CardPaymenButtonTranslations,
    storedInstrumentTranslations: StoredInstrumentButtonTranslations? = nil
) -> Payrails.CardPaymentButton
```

### Apple Pay button

```swift
public static func createApplePayButton(
    type: PKPaymentButtonType,
    style: PKPaymentButtonStyle,
    showSaveInstrument: Bool = false
) -> ApplePayElement
```

### PayPal button

```swift
public static func createPayPalButton(showSaveInstrument: Bool = false) -> PaypalElement
```

### Generic redirect button

```swift
public static func createGenericRedirectButton(
    buttonStyle: CardButtonStyle? = nil,
    translations: CardPaymenButtonTranslations,
    paymentMethodCode: String
) -> Payrails.GenericRedirectButton
```

### Stored instruments

```swift
public static func createStoredInstruments(
    style: StoredInstrumentsStyle? = nil,
    translations: StoredInstrumentsTranslations? = nil,
    showDeleteButton: Bool = false,
    showUpdateButton: Bool = false,
    showPayButton: Bool = false
) -> Payrails.StoredInstruments
```

---

## Static helpers

```swift
// Returns all stored instruments (card + PayPal)
public static func getStoredInstruments() -> [StoredInstrument]

// Returns stored instruments for a specific payment type
public static func getStoredInstruments(for type: Payrails.PaymentType) -> [StoredInstrument]

// Instrument management
public static func api(
    _ operation: String,           // "deleteInstrument" | "updateInstrument"
    _ instrumentId: String,
    _ body: UpdateInstrumentBody? = nil
) async throws -> InstrumentAPIResponse

// Runtime session state update
public static func update(_ options: UpdateOptions)

// Query session state
public static func query(_ key: PayrailsQueryKey) -> PayrailsQueryResult?
```

---

## Query API

### `PayrailsQueryKey`

```swift
public enum PayrailsQueryKey {
    case executionId
    case holderReference
    case amount
    case binLookup
    case instrumentDelete
    case instrumentUpdate
    case paymentMethodConfig(PaymentMethodFilter)
    case paymentMethodInstruments(type: Payrails.PaymentType)
}
```

### `PaymentMethodFilter`

```swift
public enum PaymentMethodFilter {
    case all
    case redirect
    case specific(String)  // paymentMethodCode
}
```

### `PayrailsQueryResult`

```swift
public enum PayrailsQueryResult {
    case string(String)
    case amount(PayrailsAmount)
    case link(PayrailsLink)
    case paymentOptions([PayrailsPaymentOption])
    case storedInstruments([StoredInstrument])
}
```

### Supporting types

```swift
public struct PayrailsAmount {
    public let value: String
    public let currency: String
}

public struct PayrailsLink {
    public let method: String?
    public let href: String?
}

public struct PayrailsPaymentOption {
    public let paymentMethodCode: String
    public let description: String?
    public let integrationType: String
    public let clientConfig: ClientConfig?

    public struct ClientConfig {
        public let displayName: String?
        public let flow: String?
        public let supportsSaveInstrument: Bool?
        public let supportsBillingInfo: Bool?
    }
}
```

---

## Updating session state

```swift
public struct UpdateOptions {
    public var amount: PayrailsAmount?
    public init(amount: PayrailsAmount? = nil)
}

// Usage
Payrails.update(UpdateOptions(amount: PayrailsAmount(value: "57.49", currency: "USD")))
```

See [How to Update Checkout Amount](how-to-update-checkout-amount.md) for the full flow.

---

## Callbacks and results

```swift
public typealias OnInitCallback = (Result<Payrails.Session, PayrailsError>) -> Void
public typealias OnPayCallback = (OnPayResult) -> Void

public enum OnPayResult {
    case success
    case authorizationFailed
    case failure
    case error(PayrailsError)
    case cancelledByUser
}
```

---

## Payment presenter protocol

Required to present view controllers during payment (e.g. 3DS challenges):

```swift
public protocol PaymentPresenter: AnyObject {
    func presentPayment(_ viewController: UIViewController)
    var encryptedCardData: String? { get set }
}
```

Typically conformed to by a `UIViewController`:

```swift
extension MyCheckoutViewController: PaymentPresenter {
    func presentPayment(_ viewController: UIViewController) {
        present(viewController, animated: true)
    }
}
```

---

## Delegate protocols

### `PayrailsCardPaymentButtonDelegate`

```swift
public protocol PayrailsCardPaymentButtonDelegate: AnyObject {
    func onPaymentButtonClicked(_ button: Payrails.CardPaymentButton)
    func onAuthorizeSuccess(_ button: Payrails.CardPaymentButton)
    func onThreeDSecureChallenge(_ button: Payrails.CardPaymentButton)
    func onAuthorizeFailed(_ button: Payrails.CardPaymentButton)
    // Optional — default implementation provided
    func onStoredInstrumentChanged(_ button: Payrails.CardPaymentButton, instrument: StoredInstrument?)
}
```

### `PayrailsCardFormDelegate`

```swift
public protocol PayrailsCardFormDelegate: AnyObject {
    func cardForm(_ view: Payrails.CardForm, didCollectCardData data: String)
    func cardForm(_ view: Payrails.CardForm, didFailWithError error: Error)
}
```

### `PayrailsApplePayButtonDelegate`

```swift
public protocol PayrailsApplePayButtonDelegate: AnyObject {
    // Called on payment result
}
```

### `PayrailsPayPalButtonDelegate`

```swift
public protocol PayrailsPayPalButtonDelegate: AnyObject {
    // Called on payment result
}
```

### `PayrailsStoredInstrumentsDelegate`

```swift
public protocol PayrailsStoredInstrumentsDelegate: AnyObject {
    func storedInstruments(_ view: Payrails.StoredInstruments, didSelectInstrument instrument: StoredInstrument)
    func storedInstruments(_ view: Payrails.StoredInstruments, didCompletePaymentForInstrument instrument: StoredInstrument)
    func storedInstruments(_ view: Payrails.StoredInstruments, didFailPaymentForInstrument instrument: StoredInstrument, error: PayrailsError)
    func storedInstruments(_ view: Payrails.StoredInstruments, didRequestDeleteInstrument instrument: StoredInstrument)
    func storedInstruments(_ view: Payrails.StoredInstruments, didRequestUpdateInstrument instrument: StoredInstrument)
}
```

---

## Error handling

### `PayrailsError`

```swift
public enum PayrailsError: Error, LocalizedError {
    case authenticationError
    case sdkNotInitialized
    case missingData(String?)
    case invalidDataFormat
    case invalidCardData
    case unknown(error: Error?)
    case unsupportedPayment(type: Payrails.PaymentType)
    case incorrectPaymentSetup(type: Payrails.PaymentType)
    case pollingFailed(String)
    case failedToDerivePaymentStatus(String)
    case finalStatusNotFoundAfterLongPoll(String)
    case longPollingFailed(underlyingError: Error?)
}
```

`PayrailsError` conforms to `LocalizedError`; use `error.errorDescription` for a human-readable message.

---

## Tokenization

```swift
public struct TokenizeOptions {
    public let storeInstrument: Bool
    public let futureUsage: FutureUsage
}

public enum FutureUsage: String {
    case cardOnFile
    case subscription
    case unscheduledCardOnFile
}
```

See [How to Tokenize a Card](how-to-tokenize-card.md).

---

## Instrument management

```swift
public struct UpdateInstrumentBody: Codable {
    // Fields depend on the update operation (e.g. isDefault)
}

public enum InstrumentAPIResponse {
    case delete(DeleteInstrumentResponse)
    case update(UpdateInstrumentResponse)
}
```

---

## Card form configuration

See [Styling Guide](merchant-styling-guide.md) for full details.

```swift
public struct CardFormConfig {
    public init(
        showNameField: Bool = false,
        showSaveInstrument: Bool = false,
        showCardIcon: Bool = false,
        showRequiredAsterisk: Bool = true,
        cardIconAlignment: CardIconAlignment = .left,
        fieldVariant: FieldVariant = .outlined,
        layout: CardLayoutConfig? = nil,
        styles: CardFormStylesConfig? = nil,
        translations: CardTranslations? = nil
    )
}

public enum FieldVariant {
    case outlined
    case filled
}

public enum CardIconAlignment {
    case left
    case right
}
```

---

## Debug

```swift
public extension Payrails {
    struct Debug {
        // Returns a SwiftUI view displaying the parsed SDK config and logs
        public static func configViewer() -> some View
    }
}

// Logs a message to both the Xcode console and the on-screen LogStore
public static func log(_ items: Any..., separator: String, terminator: String)
```
