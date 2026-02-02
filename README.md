# Payrails iOS SDK

Payrails iOS SDK provides UI components and payment flows for card payments, Apple Pay, PayPal, and redirect-based methods.

## Documentation

This README is the canonical integration guide. The `docs/` folder contains supplemental examples and flow-specific notes.

## Installation

### CocoaPods

```ruby
pod "Payrails/Checkout"
```

```bash
pod install
```

### Swift Package Manager

Use `https://github.com/payrails/ios-sdk` as the repository URL and select the `Payrails` product.

### Apple Pay capability

Enable Apple Pay in your target's Signing & Capabilities and configure a Merchant ID.

## SDK Initialization

### Async/await

```swift
import Payrails

// 1) Fetch InitData from your backend
let initData = try await Api()
    .call(
        endpoint: .initSdk(settings: settings, token: authentication.accessToken),
        type: Payrails.InitData.self
    )

// 2) Build configuration
let configuration = Payrails.Configuration(
    initData: initData,
    option: Payrails.Options(env: .dev) // .prod in production
)

// 3) Initialize the SDK
let session = try await Payrails.createSession(with: configuration)

// 4) Store the session if you need a direct reference
self.payrailsSession = session
```

Notes:
- `Payrails.createSession(with:)` is the public entry point for SDK initialization.
- `initData` is just `version` and `data`; pass it as provided by your backend.
- Creating UI components should happen on the main thread after initialization.

### Callback

```swift
Payrails.createSession(with: configuration) { result in
    switch result {
    case .success(let session):
        print("Session created: \(String(describing: session.executionId))")
    case .failure(let error):
        print("Initialization failed: \(error)")
    }
}
```

### Session lifetime guidance

- Create **one** session and reuse it during the app lifecycle.
- `Payrails.createSession(with:)` sets an internal `currentSession` used by the factory methods.

## Payment Presenter

Some payment methods require presenting additional UI (3DS, PayPal login, redirects). Implement `PaymentPresenter` in the view controller that owns the checkout UI.

```swift
final class CheckoutViewController: UIViewController, PaymentPresenter {
    func presentPayment(_ viewController: UIViewController) {
        present(viewController, animated: true)
    }

    // Used by the SDK for card payments
    var encryptedCardData: String?
}
```

## Card Payments

Card payments use two components:

1. `Payrails.CardForm` to collect and encrypt card data
2. `Payrails.CardPaymentButton` to submit the payment

### Create a Card Form

```swift
let cardForm = Payrails.createCardForm(
    config: nil,
    showSaveInstrument: false
)

view.addSubview(cardForm)
```

You can customize styles and translations using `CardFormConfig`:

```swift
let customConfig = CardFormConfig(
    showNameField: true,
    showSaveInstrument: true,
    styles: customStyles, // Optional CardFormStylesConfig
    translations: customTranslations // Optional CardTranslations
)

let cardForm = Payrails.createCardForm(config: customConfig, showSaveInstrument: true)
```

### Create a Card Payment Button

`createCardPaymentButton` requires a session **and** a card form to exist. Call `createCardForm(...)` first.

```swift
let buttonTranslations = CardPaymenButtonTranslations(label: "Pay Now")
let payButton = Payrails.createCardPaymentButton(
    buttonStyle: nil,
    translations: buttonTranslations
)

payButton.delegate = self
payButton.presenter = self
```

Notes:
- When using `CardPaymentButton`, **do not set** `cardForm.delegate` manually. The button sets itself as the delegate to receive encrypted card data.
- Use `PayrailsCardPaymentButtonDelegate` for success/failure callbacks.

## Apple Pay

```swift
let applePayButton = Payrails.createApplePayButton(
    type: .checkout,
    style: .black,
    showSaveInstrument: false
)

applePayButton.delegate = self
applePayButton.presenter = self
```

## PayPal

```swift
let payPalButton = Payrails.createPayPalButton(showSaveInstrument: true)
payPalButton.delegate = self
payPalButton.presenter = self
```

## Redirect Payment Methods

For redirect-based methods (e.g., iDEAL), use a generic redirect button and the payment method code from your backend configuration:

```swift
let buttonTranslations = CardPaymenButtonTranslations(label: "Pay with iDEAL")
let buttonStyle = CardButtonStyle(
    backgroundColor: .systemBlue,
    textColor: .white,
    cornerRadius: 8
)

let idealButton = Payrails.createGenericRedirectButton(
    buttonStyle: buttonStyle,
    translations: buttonTranslations,
    paymentMethodCode: "ideal"
)

idealButton.presenter = self
idealButton.delegate = self
```

## Stored Instruments

### Accessing stored instruments

```swift
let cards = session.storedInstruments(for: .card)
let paypals = session.storedInstruments(for: .payPal)
```

Or via the static helper (uses the current session):

```swift
let payPalInstruments = Payrails.getStoredInstruments(for: .payPal)
```

### Displaying stored instruments

```swift
let storedInstrumentsView = Payrails.createStoredInstruments(
    showDeleteButton: true,
    showUpdateButton: true,
    showPayButton: true
)

storedInstrumentsView.delegate = self
storedInstrumentsView.presenter = self
```

### Displaying a single stored instrument

```swift
let instrumentView = Payrails.createStoredInstrumentView(
    instrument: instrument,
    showDeleteButton: true,
    showUpdateButton: true,
    showPayButton: true
)

instrumentView.delegate = self
instrumentView.setPresenter(self)
```

### Managing stored instruments

Use `Payrails.api` to delete or update a stored instrument:

```swift
// Delete
let result = try await Payrails.api("deleteInstrument", instrumentId)

// Update (set as default)
let body = UpdateInstrumentBody(default: true)
let result = try await Payrails.api("updateInstrument", instrumentId, body)
```

## Debugging

```swift
// Toggle the SDK on-screen log overlay
Payrails.DebugManager.shared.toggleLogView()

// Present a SwiftUI viewer with the parsed SDK config
let debugView = Payrails.Debug.configViewer(session: session)
let hostingController = UIHostingController(rootView: debugView)
present(hostingController, animated: true)

// Log entries to the SDK log store
Payrails.log("Some message")
```

## Customization Notes

The current implementation exposes styling, fonts, colors, and text labels, but has these limitations:

- Field order and placement are fixed (`[1, 1, 3]` with name, `[1, 3]` without name).
- Field dimensions are applied internally; custom Auto Layout constraints are limited.
- The save-instrument toggle layout is not configurable.
- Some low-level styling (card-brand icon, asterisk visibility) is not exposed via `CardFormConfig`.

## Security Policy

### Reporting a Vulnerability

If you find any vulnerability in Payrails iOS SDK, do not hesitate to _report them_.

1. Send the disclosure to security@payrails.com

2. Describe the vulnerability.

   If you have a fix, that is most welcome -- please attach or summarize it in your message!

3. We will evaluate the vulnerability and, if necessary, release a fix or mitigating steps to address it. We will contact you to let you know the outcome, and will credit you in the report.

   Please **do not disclose the vulnerability publicly** until a fix is released!

4. Once we have either a) published a fix, or b) declined to address the vulnerability for whatever reason, you are free to publicly disclose it.
