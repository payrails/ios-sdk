# Payrails iOS SDK

Payrails iOS SDK provides UI components and payment flows for card payments, Apple Pay, PayPal, and redirect-based methods.

## Documentation

This README is the canonical integration guide. The `docs/` folder contains supplemental examples and flow-specific notes.

## Release Notes

See [CHANGELOG.md](CHANGELOG.md) for a full history of releases, features, and fixes.

## CI Validation

The repository uses GitHub Actions CI checks for the SDK:
- Triggered on pull requests targeting `main`
- Triggered on direct pushes to `main` (post-merge verification)

CI runs three checks:
- Build (`./scripts/ci/build.sh`)
- Lint (`./scripts/ci/lint.sh`)
- Test (`./scripts/ci/test.sh`)

### Local pre-PR checks

Run the same commands locally before opening a pull request:

```bash
./scripts/ci/build.sh
./scripts/ci/lint.sh
./scripts/ci/test.sh
```

### CI prerequisites

- GitHub-hosted macOS runner (`macos-15`) with Xcode 16.2 selected in workflow
- Shared Xcode scheme: `Payrails.xcodeproj/xcshareddata/xcschemes/Payrails.xcscheme`
- Canonical simulator destination: `platform=iOS Simulator,name=iPhone 15,OS=latest`
- Workflow definition: `.github/workflows/ci.yaml`

### Required checks and rollback

Repository maintainers should configure branch protection on `main` to require the CI check:
- `CI / Validate SDK (build, lint, test)`

If rollback is needed:
1. Remove/disable the required CI status check in branch protection.
2. Revert `.github/workflows/ci.yaml` and `scripts/ci/*`.
3. Re-run CI to confirm repository returns to the previous state.

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

### Creating InitData

You can create `InitData` directly using the public initializer. This gives you full control over how you fetch and parse the initialization payload from your backend:

```swift
import Payrails

- pass the client `init` call response to the frontend 

// Create InitData directly
let initData = Payrails.InitData(version: version, data: payload)
```

This approach:
- **Avoids coupling** your response parsing to Payrails SDK objects.
- **Gives flexibility** — your backend doesn't need to follow a specific naming or response structure.

Alternatively, if your backend returns a response matching the SDK's expected structure, you can decode it directly:

```swift
let initData = try JSONDecoder().decode(Payrails.InitData.self, from: responseData)
```

### Async/await

```swift
import Payrails

// 1) Fetch version and payload from your backend
let (version, payload) = try await fetchInitDataFromBackend()

// 2) Create InitData
let initData = Payrails.InitData(version: version, data: payload)

// 3) Build configuration
let configuration = Payrails.Configuration(
    initData: initData,
    option: Payrails.Options(env: .test) // .production in production
)

// 4) Initialize the SDK
let session = try await Payrails.createSession(with: configuration)

// 5) Store the session if you need a direct reference
self.payrailsSession = session
```

Notes:
- `Payrails.createSession(with:)` is the public entry point for SDK initialization.
- `initData` requires `version` (String) and `data` (String); extract these from your backend response however you prefer.
- Creating UI components should happen on the main thread after initialization.

### Callback

```swift
Payrails.createSession(with: configuration) { result in
    switch result {
    case .success(let session):
        print("Session created: \(String(describing: Payrails.executionId))")
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
    buttonStyle: CardButtonStyle(height: 56), // Partial styles are merged over defaults
    translations: buttonTranslations
)

payButton.delegate = self
payButton.presenter = self
```

Notes:
- When using `CardPaymentButton`, **do not set** `cardForm.delegate` manually. The button sets itself as the delegate to receive encrypted card data.
- Use `PayrailsCardPaymentButtonDelegate` for success/failure callbacks.
- Button customization should be done via `createCardPaymentButton`.
- `CardButtonStyle.height` is supported in card-form mode.
- Partial button styles are merged with defaults, so passing only `height` keeps default visuals.
- SDK default colors semantic iOS colors and adapt to light/dark mode.
- Merchant-provided style colors always take precedence over SDK defaults.

### Tokenizing a Card (Save Without Payment)

Use `cardForm.tokenize()` to encrypt card data and register it in the vault as a stored instrument without processing a payment:

```swift
let cardForm = Payrails.createCardForm()

do {
    let response = try await cardForm.tokenize(options: TokenizeOptions(
        storeInstrument: true,
        futureUsage: .cardOnFile // .subscription or .unscheduledCardOnFile
    ))
    print("Instrument saved: \(response.id)")
    print("Card ending in: \(response.data.suffix ?? "")")
} catch {
    print("Tokenization failed: \(error)")
}
```

The returned `SaveInstrumentResponse` contains instrument metadata (ID, BIN, suffix, network, expiry, fingerprint).

`TokenizeOptions` defaults:
- `storeInstrument`: `false`
- `futureUsage`: `.cardOnFile`

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
let cards = Payrails.getStoredInstruments(for: .card)
let paypals = Payrails.getStoredInstruments(for: .payPal)
```

> **Instrument visibility:** `getStoredInstruments(for:)` returns instruments whose status is `"enabled"` or `"created"` (case-insensitive). A freshly tokenized card typically has status `"created"` until it transitions to `"enabled"`, so it will appear immediately after a session re-init without needing to wait for the status change.

> **Refreshing after tokenization:** Stored instruments are baked into the session at init time. To see a newly saved card, re-initialize the session by calling `Payrails.createSession(with:)` with fresh init data from your backend, then rebuild any `StoredInstruments` UI components.

### Default instrument

Each `StoredInstrument` exposes `isDefault: Bool`, decoded from the `default` field in the server response. Use it to highlight the holder's default payment method in your UI or to conditionally enable a "Set as Default" action:

```swift
let cards = Payrails.getStoredInstruments(for: .card)
let defaultCard = cards.first { $0.isDefault }

// Disable "Set as Default" when the card is already default
setDefaultButton.isEnabled = !selectedCard.isDefault
```

To mark an instrument as default:

```swift
let response = try await session.updateInstrument(
    instrumentId: instrumentId,
    body: UpdateInstrumentBody(default: true)
)
```

> `isDefault` reflects the value baked into the session at init time. After calling `updateInstrument`, re-initialize the session to get updated `isDefault` values.

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

### Binding stored instruments to a payment button

You can dynamically switch a `CardPaymentButton` between card form mode and stored instrument mode at runtime. This lets users pick a saved card from a list and pay with one tap.

**Auto-binding via StoredInstruments list:**

```swift
let storedInstrumentsView = Payrails.createStoredInstruments(showPayButton: false)
let payButton = Payrails.createCardPaymentButton(translations: buttonTranslations)

// Wire the list to the button — selecting an instrument switches the button automatically
storedInstrumentsView.bindCardPaymentButton(payButton)
```

**Manual binding:**

```swift
// Switch to stored instrument mode
payButton.setStoredInstrument(instrument)

// Revert to card form mode
payButton.clearStoredInstrument()
```

**Listening for changes:**

Implement the optional delegate method to react when the instrument changes:

```swift
func onStoredInstrumentChanged(_ button: Payrails.CardPaymentButton, instrument: StoredInstrument?) {
    if let instrument = instrument {
        print("Paying with: \(instrument.description ?? instrument.id)")
    } else {
        print("Switched to card form mode")
    }
}
```

### Managing stored instruments

Call the typed methods on your `Payrails.Session` to delete or update a stored instrument:

```swift
// Delete
let response = try await session.deleteInstrument(instrumentId: instrumentId)

// Update (set as default)
let response = try await session.updateInstrument(
    instrumentId: instrumentId,
    body: UpdateInstrumentBody(default: true)
)
```

## Payment Amount Update

After initializing a session, you can update the payment amount before executing a payment. This is useful when the backend updates the execution (e.g., via a lookup action) and the SDK needs to reflect the new values.

```swift
Payrails.update(UpdateOptions(amount: PayrailsAmount(value: "25.50", currency: "USD")))
```

> Both `value` and `currency` are required. If either is nil, the amount is not changed. `update()` only modifies local SDK state — the backend execution should already reflect the new values.

## Querying SDK State

`Payrails.query(_:)` is a read-only accessor for session configuration state. Use it to retrieve execution details, payment method configuration, stored instruments, and API links without holding a reference to the session object.

```swift
let result = Payrails.query(.holderReference)
```

Returns `nil` if the SDK has not been initialized or the requested value is not present.

### Available query keys

| Key | Return case | Description |
|-----|-------------|-------------|
| `.holderReference` | `.string(String)` | The holder reference for the current session |
| `.amount` | `.amount(PayrailsAmount)` | Payment amount and currency |
| `.executionId` | `.string(String)` | The execution ID |
| `.binLookup` | `.link(PayrailsLink)` | API link for BIN lookup |
| `.instrumentDelete` | `.link(PayrailsLink)` | API link for deleting a stored instrument |
| `.instrumentUpdate` | `.link(PayrailsLink)` | API link for updating a stored instrument |
| `.paymentMethodConfig(PaymentMethodFilter)` | `.paymentOptions([PayrailsPaymentOption])` | Payment method configuration (see below) |
| `.paymentMethodInstruments(type:)` | `.storedInstruments([StoredInstrument])` | Stored instruments for a payment type |

### Examples

```swift
// Holder reference
if case .string(let ref) = Payrails.query(.holderReference) {
    print("Holder: \(ref)")
}

// Payment amount
if case .amount(let amount) = Payrails.query(.amount) {
    print("\(amount.value) \(amount.currency)")
}

// Execution ID
if case .string(let id) = Payrails.query(.executionId) {
    print("Execution: \(id)")
}

// BIN lookup link
if case .link(let link) = Payrails.query(.binLookup) {
    print("\(link.method ?? "") \(link.href ?? "")")
}

// Instrument management links
if case .link(let link) = Payrails.query(.instrumentDelete) {
    print("Delete URL: \(link.href ?? "")")
}
if case .link(let link) = Payrails.query(.instrumentUpdate) {
    print("Update URL: \(link.href ?? "")")
}

// Payment method configuration
// Use PaymentMethodFilter to specify which methods to retrieve:

// A specific payment method code:
if case .paymentOptions(let options) = Payrails.query(.paymentMethodConfig(.specific("card"))) {
    print("Card integration: \(options.first?.integrationType ?? "")")
}

// All available methods:
if case .paymentOptions(let options) = Payrails.query(.paymentMethodConfig(.all)) {
    options.forEach { print($0.paymentMethodCode) }
}

// Only redirect-flow methods:
if case .paymentOptions(let options) = Payrails.query(.paymentMethodConfig(.redirect)) {
    options.forEach { print($0.paymentMethodCode) }
}

// Stored instruments for a payment type
if case .storedInstruments(let instruments) = Payrails.query(.paymentMethodInstruments(type: .card)) {
    instruments.forEach { print($0.id) }
}
```

### PayrailsPaymentOption fields

```swift
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

The current implementation exposes styling, fonts, colors, and text labels, with these remaining limitations:

- The save-instrument toggle layout is not configurable.
- All fields in a multi-element row share equal width (no column-span or weighted widths).

### Card Form Customization

The SDK supports advanced card form customization, including:
- Show/hide static empty-state field icons (`showCardIcon`)
- Card icon alignment (`cardIconAlignment`)
- Show/hide required asterisk (`showRequiredAsterisk`)
- Configurable field and section spacing (`fieldSpacing`, `sectionSpacing`)
- Field-to-container insets via `fieldInsets` on the base style (independent of text padding)
- Card payment button customization via `createCardPaymentButton` (`CardButtonStyle`, including `height`)
- Configurable field arrangement and ordering via `CardLayoutConfig`
- Field border variant (`fieldVariant`): `.outlined` for full box borders or `.filled` for bottom-line-only styling

### Field Insets

By default, fields stretch to fill their container with 6pt horizontal insets. Use `fieldInsets` on the base style to control the spacing between a field and its container edge, independently of the text padding inside the field:

```swift
let styles = CardFormStylesConfig(
    allInputFieldStyles: CardFieldSpecificStyles(
        base: CardStyle(
            padding: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10),  // text inset inside field
            fieldInsets: .fieldInsets(left: 24, right: 24)                      // field-to-container spacing
        )
    )
)
```

The convenience method `.fieldInsets(top:left:bottom:right:)` provides defaults of `(0, 6, 0, 6)` — only specify the sides you want to change:

```swift
.fieldInsets(top: 8)                  // only change top
.fieldInsets(left: 24, right: 24)     // only change horizontal
.zero                                  // edge-to-edge (no insets)
```

When an explicit `width` is set on a field, `fieldInsets` is ignored and the field uses a fixed-width constraint instead.

Card icon and clear button behavior on iOS:
- `showCardIcon: true`: shows static empty-state icons for supported fields
- `showCardIcon: false`: hides static empty-state icons
- Card-number network detection remains enabled (brand icon updates based on PAN)
- Clear button (`x`) is always available on iOS for non-card-number fields when they contain input
- Card number does not show the clear button, so network icon behavior remains visible
- The same clear-button behavior applies to both combined expiry (`EXPIRATION_DATE`) and split expiry (`EXPIRATION_MONTH` + `EXPIRATION_YEAR`) layouts

Error text behavior in composable card forms:
- Error labels support multiline wrapping by default.
- `errorTextStyle.height`, `errorTextStyle.minHeight`, and `errorTextStyle.maxHeight` are applied to row error labels.
- The form requests a layout refresh when row error text changes so wrapped errors can expand the form height.

#### Field variant

The `fieldVariant` property controls the border rendering style on each input field:

- `.outlined` (default) — renders full box borders using `borderColor`, `borderWidth`, and `cornerRadius` from the configured `Style`
- `.filled` — renders a single bottom line using the same `borderColor` and `borderWidth`, while clearing box borders and corner radius

```swift
// Outlined (default)
let outlinedConfig = CardFormConfig(fieldVariant: .outlined)

// Filled
let filledConfig = CardFormConfig(fieldVariant: .filled)
```

Both variants respect all other style properties (background color, font, text color, padding) and work with any `CardLayoutConfig`.

#### Example Usage

```swift
let config = CardFormConfig(
    showNameField: true,
    showSaveInstrument: false,
    showCardIcon: true,
    cardIconAlignment: .right,
    showRequiredAsterisk: false,
    fieldVariant: .outlined,
    styles: CardFormStylesConfig(
        fieldSpacing: 12,
        sectionSpacing: 20
    )
)

let payButton = Payrails.createCardPaymentButton(
    buttonStyle: CardButtonStyle(
        height: 50,
        backgroundColor: .systemBlue,
        textColor: .white,
        font: .boldSystemFont(ofSize: 16),
        cornerRadius: 8
    ),
    translations: CardPaymenButtonTranslations(label: "Pay")
)
```

- `createCardPaymentButton(... buttonStyle: ...)`: Styles the pay button and supports `height`
- `sectionSpacing`: Sets the vertical spacing between the card form and the pay button (default is 16pt if not set)
- `fieldSpacing`: Sets the spacing between input fields (see CardForm)
- If color properties are omitted, SDK fallbacks use theme-aware semantic iOS colors.

#### Layout presets

```swift
let standard = CardLayoutConfig.standard
let compact = CardLayoutConfig.compact
let minimal = CardLayoutConfig.minimal
```

#### Custom rows and field order

```swift
let config = CardFormConfig(
    showNameField: true,
    layout: .custom(
        [[.CARD_NUMBER], [.CARDHOLDER_NAME], [.EXPIRATION_DATE, .CVV]],
        fieldOrder: [.CARD_NUMBER, .EXPIRATION_DATE, .CVV, .CARDHOLDER_NAME]
    )
)
```

- Use `.EXPIRATION_DATE` to render a single combined `MM/YY` field.
- `fieldOrder` reorders fields across the configured rows while preserving row sizes.
- Custom layouts must include `CARD_NUMBER`, `CVV`, and expiry (`EXPIRATION_DATE` or both `EXPIRATION_MONTH` + `EXPIRATION_YEAR`) to be submittable.
- Unsupported field types in custom rows are ignored.
- If all configured fields are unsupported, or required card fields are missing after sanitization, the SDK falls back to legacy default rows.
- If `layout` is omitted, legacy rows remain the default:
  - With `showNameField: true`: `[[.CARD_NUMBER], [.CARDHOLDER_NAME], [.CVV, .EXPIRATION_MONTH, .EXPIRATION_YEAR]]`
  - With `showNameField: false`: `[[.CARD_NUMBER], [.CVV, .EXPIRATION_MONTH, .EXPIRATION_YEAR]]`

## Security Policy

### Reporting a Vulnerability

If you find any vulnerability in Payrails iOS SDK, do not hesitate to _report them_.

1. Send the disclosure to security@payrails.com

2. Describe the vulnerability.

   If you have a fix, that is most welcome -- please attach or summarize it in your message!

3. We will evaluate the vulnerability and, if necessary, release a fix or mitigating steps to address it. We will contact you to let you know the outcome, and will credit you in the report.

   Please **do not disclose the vulnerability publicly** until a fix is released!

4. Once we have either a) published a fix, or b) declined to address the vulnerability for whatever reason, you are free to publicly disclose it.
