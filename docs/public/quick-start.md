# Quick Start

Get up and running with the Payrails iOS SDK in about 15 minutes. By the end you will have a working card payment screen in your app.

## Prerequisites

- Xcode 14+
- iOS 14.0+ deployment target
- Swift 5.0+
- A Payrails merchant account and a backend that can fetch an init payload

---

## Step 1: Install the SDK

### CocoaPods

Add the dependency to your `Podfile`:

```ruby
pod 'Payrails/Checkout', '~> 1.25'
```

Then run:

```bash
pod install
```

> Open the `.xcworkspace` file, not `.xcodeproj`, after installing pods.

### Swift Package Manager

In Xcode, go to **File → Add Package Dependencies** and add:

```
https://github.com/payrails/ios-sdk.git
```

Or add it directly to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/payrails/ios-sdk.git", from: "1.25.0")
]
```

---

## Step 2: Enable Apple Pay capability (optional)

If you plan to use Apple Pay, add the **Apple Pay** capability in Xcode under **Signing & Capabilities** and provide your merchant identifier.

---

## Step 3: Fetch the init payload from your backend

The SDK requires an init payload that your backend fetches from the Payrails API. This payload is a base64-encoded JSON string along with a version string.

```swift
// Your backend call — implementation depends on your networking layer
func fetchInitPayload() async throws -> (data: String, version: String) {
    // Call your backend, which calls the Payrails /checkout/initialize endpoint
    // Returns the `data` and `version` fields from the Payrails response
}
```

---

## Step 4: Initialize the SDK session

### Async/await

```swift
import Payrails

let initData = Payrails.InitData(
    version: "2",          // version returned from your backend
    data: "<base64-payload>"  // data returned from your backend
)

let configuration = Payrails.Configuration(
    initData: initData,
    option: Payrails.Options(env: .production) // use .test for sandbox
)

do {
    let session = try await Payrails.createSession(with: configuration)
    // session is ready; store it or proceed to build your UI
} catch {
    print("SDK initialization failed:", error.localizedDescription)
}
```

### Callback

```swift
Payrails.createSession(with: configuration) { result in
    switch result {
    case .success(let session):
        // session is ready
    case .failure(let error):
        print("SDK initialization failed:", error.localizedDescription)
    }
}
```

---

## Step 5: Build a card payment screen

Payrails provides UIKit-based elements. Add them to your view hierarchy:

```swift
import UIKit
import Payrails

class CheckoutViewController: UIViewController, PaymentPresenter {

    var encryptedCardData: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        // 1. Create the card form
        let cardForm = Payrails.createCardForm()

        // 2. Create the pay button
        let payButton = Payrails.createCardPaymentButton(
            translations: CardPaymenButtonTranslations(label: "Pay now")
        )
        payButton.delegate = self
        payButton.presenter = self  // PaymentPresenter: required to present 3DS challenges

        // 3. Add to view hierarchy
        view.addSubview(cardForm)
        view.addSubview(payButton)

        // 4. Layout (use Auto Layout or frames as preferred)
        cardForm.translatesAutoresizingMaskIntoConstraints = false
        payButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            cardForm.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            cardForm.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            cardForm.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            payButton.topAnchor.constraint(equalTo: cardForm.bottomAnchor, constant: 16),
            payButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            payButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    // PaymentPresenter: called when a view controller must be presented (e.g. 3DS)
    func presentPayment(_ viewController: UIViewController) {
        present(viewController, animated: true)
    }
}
```

---

## Step 6: Handle payment results

Conform to `PayrailsCardPaymentButtonDelegate`:

```swift
extension CheckoutViewController: PayrailsCardPaymentButtonDelegate {

    func onPaymentButtonClicked(_ button: Payrails.CardPaymentButton) {
        // Optional: show a loading indicator
    }

    func onAuthorizeSuccess(_ button: Payrails.CardPaymentButton) {
        // Payment succeeded — navigate to confirmation screen
    }

    func onAuthorizeFailed(_ button: Payrails.CardPaymentButton) {
        // Payment failed or was declined — show error to user
    }

    func onThreeDSecureChallenge(_ button: Payrails.CardPaymentButton) {
        // 3DS challenge is being presented — optional hook
    }
}
```

---

## Step 7: Test with the sandbox environment

Change the environment to `.test` when initializing the session:

```swift
let configuration = Payrails.Configuration(
    initData: initData,
    option: Payrails.Options(env: .test)
)
```

Use Payrails sandbox card numbers to test different payment outcomes.

---

## What's next

- [Concepts](concepts.md) — understand the Session, Elements, and Delegates mental model
- [Styling Guide](styling-guide.md) — customise card form and button appearance
- [How to Tokenize a Card](how-to-tokenize-card.md) — save a card without immediate payment
- [How to Query Session Data](how-to-query-session-data.md) — read execution ID, amount, and more
- [SDK API Reference](sdk-api-reference.md) — complete API documentation
- [Troubleshooting](troubleshooting.md) — common issues and fixes
