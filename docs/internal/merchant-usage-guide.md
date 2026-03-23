# Merchant Usage Guide

In-depth integration patterns for merchant developers. This is the internal-facing counterpart to the public [Quick Start](../public/quick-start.md).

---

## Requirements

| Requirement | Value |
|---|---|
| iOS deployment target | 14.0+ |
| Swift version | 5.0+ |
| Xcode | 14+ |
| CocoaPods | 1.11+ |

---

## Installation

### CocoaPods

```ruby
platform :ios, '14.0'
use_frameworks!

target 'MyApp' do
  pod 'Payrails/Checkout', '~> 1.25'
end
```

```bash
pod install
open MyApp.xcworkspace
```

### Swift Package Manager

Add via Xcode: **File → Add Package Dependencies**

```
https://github.com/payrails/ios-sdk.git
```

---

## Session lifecycle

A session wraps one checkout execution. The typical lifecycle is:

```
viewDidLoad → fetch init payload from backend → createSession → build UI → payment
```

Session creation is a lightweight local operation (JSON parsing + CSE init). The network call happens on your backend, not in the SDK.

### Async/await pattern

```swift
class CheckoutViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await initializePayrails() }
    }

    private func initializePayrails() async {
        do {
            let payload = try await MyBackend.fetchInitPayload()
            let initData = Payrails.InitData(version: payload.version, data: payload.data)
            let config = Payrails.Configuration(
                initData: initData,
                option: Payrails.Options(env: .prod)
            )
            _ = try await Payrails.createSession(with: config)
            buildPaymentUI()
        } catch {
            showError(error.localizedDescription)
        }
    }
}
```

### Callback pattern

```swift
Payrails.createSession(with: config) { [weak self] result in
    DispatchQueue.main.async {
        switch result {
        case .success:
            self?.buildPaymentUI()
        case .failure(let error):
            self?.showError(error.localizedDescription)
        }
    }
}
```

---

## Card payment

### Minimal card form

```swift
func buildPaymentUI() {
    let cardForm = Payrails.createCardForm()
    let payButton = Payrails.createCardPaymentButton(
        translations: CardPaymenButtonTranslations(label: "Pay")
    )
    payButton.delegate = self
    payButton.presenter = self

    // Layout with Auto Layout
    [cardForm, payButton].forEach {
        $0.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview($0)
    }

    NSLayoutConstraint.activate([
        cardForm.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
        cardForm.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
        cardForm.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        payButton.topAnchor.constraint(equalTo: cardForm.bottomAnchor, constant: 16),
        payButton.leadingAnchor.constraint(equalTo: cardForm.leadingAnchor),
        payButton.trailingAnchor.constraint(equalTo: cardForm.trailingAnchor),
    ])
}
```

### With name field and save toggle

```swift
let config = CardFormConfig(
    showNameField: true,
    showSaveInstrument: true,
    fieldVariant: .outlined,
    layout: .compact
)
let cardForm = Payrails.createCardForm(config: config, showSaveInstrument: true)
```

### Handling payment delegate callbacks

```swift
extension CheckoutViewController: PayrailsCardPaymentButtonDelegate, PaymentPresenter {

    var encryptedCardData: String?

    func presentPayment(_ viewController: UIViewController) {
        present(viewController, animated: true)
    }

    func onPaymentButtonClicked(_ button: Payrails.CardPaymentButton) {
        activityIndicator.startAnimating()
    }

    func onAuthorizeSuccess(_ button: Payrails.CardPaymentButton) {
        activityIndicator.stopAnimating()
        // IMPORTANT: confirm with your backend before fulfilling the order
        MyBackend.confirmOrder(executionId: executionId) { [weak self] confirmed in
            DispatchQueue.main.async {
                confirmed ? self?.showSuccess() : self?.showError("Backend confirmation failed")
            }
        }
    }

    func onAuthorizeFailed(_ button: Payrails.CardPaymentButton) {
        activityIndicator.stopAnimating()
        showError("Payment was not completed. Please try again.")
    }

    func onThreeDSecureChallenge(_ button: Payrails.CardPaymentButton) {
        // 3DS challenge is being presented — optionally update UI
    }
}
```

---

## Stored instruments

### Render a list with pay buttons

```swift
let instruments = Payrails.createStoredInstruments(
    showDeleteButton: true,
    showUpdateButton: true,
    showPayButton: true
)
instruments.delegate = self
instruments.presenter = self
view.addSubview(instruments)
```

### Bind to a card payment button

This pattern lets one pay button handle both new card entry and stored instrument selection:

```swift
let cardForm = Payrails.createCardForm()
let payButton = Payrails.createCardPaymentButton(translations: translations)
let instruments = Payrails.createStoredInstruments()

instruments.bindCardPaymentButton(payButton)
// When user selects an instrument → payButton switches to stored instrument mode
// When user deselects → payButton reverts to card form mode
```

### Manual instrument management

```swift
extension CheckoutViewController: PayrailsStoredInstrumentsDelegate {
    func storedInstruments(_ view: Payrails.StoredInstruments,
                           didRequestDeleteInstrument instrument: StoredInstrument) {
        // Show confirmation alert, then:
        Task {
            let response = try await Payrails.api("deleteInstrument", instrument.id)
            // Refresh the instruments view
            view.refreshInstruments()
        }
    }

    func storedInstruments(_ view: Payrails.StoredInstruments,
                           didRequestUpdateInstrument instrument: StoredInstrument) {
        let body = UpdateInstrumentBody(/* isDefault: true */)
        Task {
            let response = try await Payrails.api("updateInstrument", instrument.id, body)
        }
    }
}
```

---

## Apple Pay

```swift
import PassKit

let applePayButton = Payrails.createApplePayButton(
    type: .buy,
    style: .black
)
applePayButton.delegate = self
view.addSubview(applePayButton)

// Check availability before showing the button
if !session.isApplePayAvailable {
    applePayButton.isHidden = true
}
```

---

## PayPal

```swift
let payPalButton = Payrails.createPayPalButton()
payPalButton.delegate = self
view.addSubview(payPalButton)
```

---

## Generic redirect

```swift
let iDEALButton = Payrails.createGenericRedirectButton(
    translations: CardPaymenButtonTranslations(label: "Pay with iDEAL"),
    paymentMethodCode: "ideal"
)
iDEALButton.delegate = self
view.addSubview(iDEALButton)
```

---

## Payment amount update

When the user changes the order total (tip, shipping tier, coupon):

```swift
// 1. Update your backend first
try await myBackend.updateExecutionAmount(value: "57.49", currency: "USD")

// 2. Sync the SDK
Payrails.update(UpdateOptions(
    amount: PayrailsAmount(value: "57.49", currency: "USD")
))
```

Both steps are required. See [How to Update Checkout Amount](../public/how-to-update-checkout-amount.md).

---

## Retry and failure handling

- Do not retry a failed payment by simply calling `pay()` again on the same button. Instead, re-initialize the session if you receive `.authorizationFailed` (token may be expired).
- For `.failure` results (payment declined), the session is still valid — you can present a different payment method or ask the user to retry with a different card.
- Long-poll timeouts (`finalStatusNotFoundAfterLongPoll`) are transient. Direct the user to your order history screen to check the final status.

---

## Debugging in development

```swift
// Check SDK config at runtime
if let configView = Payrails.Debug.configViewer() as? UIView {
    // Embed in a debug overlay
}

// Or use the SwiftUI debug viewer
import SwiftUI
let hostingController = UIHostingController(rootView: Payrails.Debug.configViewer())
present(hostingController, animated: true)
```

Also see [Troubleshooting](../public/troubleshooting.md).
