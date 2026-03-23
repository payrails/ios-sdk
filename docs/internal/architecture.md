# Architecture

Internal architecture reference for SDK contributors.

---

## Module layout

The SDK is distributed as a single target with a flat namespace. There is no separate "core" vs "UI" module split (unlike the Android SDK's `payrails-core` / `payrails-ui-compose` distinction). All sources live under:

```
Payrails/Classes/Public/
```

Despite the folder name, not everything in this path is actually public. Swift's `public` and `internal` modifiers govern visibility at the language level. The folder name is a historical artifact from CocoaPods source layout conventions.

### CocoaPods subspec

```ruby
spec.subspec 'Checkout' do |checkout|
    checkout.source_files = "Payrails/Classes/Public/**/*.{swift}"
    checkout.resources    = "Payrails/Classes/Public/Assets/*.xcassets"
    checkout.dependency   'PayPalCheckout'
    checkout.dependency   'PayrailsCSE'
end
```

Consumers install `pod 'Payrails/Checkout'`. There is intentionally only one subspec to keep the integration surface simple.

### Swift Package Manager target

```swift
.target(
    name: "Payrails",
    dependencies: ["PayrailsCSE", "PayPalCheckout"],
    path: "Payrails",
    resources: [.process("Classes/Public/Assets/Media.xcassets")]
)
```

---

## Visibility conventions

| Access modifier | Meaning in this codebase |
|---|---|
| `public` | Part of the merchant-facing API. Every change is a potential breaking change. |
| `internal` (default) | SDK implementation detail. Can be refactored freely. |
| `private` / `fileprivate` | Scoped to type or file. |

The public API surface is tracked in [`public-api-audit.md`](public-api-audit.md).

---

## Key subsystems

### Session (`PayrailsSession.swift`)

`Payrails.Session` is the central coordinator. It:

1. Parses the base64-encoded init payload into `SDKConfig` (internal type)
2. Initialises `PayrailsCSE` for card encryption
3. Initialises `PayrailsAPI` for network calls
4. Holds the active `PaymentHandler` and in-flight `Task`
5. Implements `PaymentHandlerDelegate` to receive handler callbacks and translate them to `OnPayResult`

The session is stored in a static `currentSession` variable on `Payrails`. Factory methods read it via `getCurrentSession()`. This is a deliberate design choice: merchants do not pass the session around; they call static methods.

### Payment handlers (`PaymentHelpers/`)

Each payment method has a handler class conforming to the `PaymentHandler` protocol:

| Handler | Payment method |
|---|---|
| `CardPaymentHandler` | Card (card form + CSE encryption) |
| `ApplePayHandler` | Apple Pay (PassKit sheet) |
| `PayPalHandler` | PayPal (PayPalCheckout SDK) |
| `GenericRedirectHandler` | Redirect-based methods |

Handlers are created lazily in `Session.prepareHandler(for:)` and held weakly by the session. When the session is deallocated, any running payment is cancelled.

### Vault layer (`Vault/`)

The vault subsystem wraps the Skyflow iOS SDK (`PayrailsCSE`). Key types:

- `Client` — the Skyflow vault client
- `Container<T>` / `ComposableContainer` — field containers
- `TextField` (aliased as `SkyflowElement`) — secure text input
- `BaseElement` — protocol shared by all vault elements

Card fields rendered in `Payrails.CardForm` are `TextField` instances backed by the Skyflow vault. Card data never passes through the host app's memory in plaintext.

### Networking (`PaymentHelpers/PayrailsAPI.swift`)

`PayrailsAPI` wraps `URLSession`. Key design decisions:

- All requests use the execution links from `SDKConfig` (not hardcoded URLs). This means the backend controls the API endpoints via the init payload.
- Long-polling is used for payment status confirmation (card, PayPal). The polling loop uses `Task` cancellation for clean teardown.
- A retry mechanism (`confirmPaymentWithRetry`) handles transient network failures for PayPal flows (max 2 retries).
- `isRunning` flag on `PayrailsAPI` tracks payment-in-progress state, preventing concurrent payment attempts.

---

## Static session pattern

```
Payrails (static)
  ├── currentSession: Payrails.Session?
  ├── currentCardForm: Payrails.CardForm?
  └── factory methods: createCardForm(), createCardPaymentButton(), ...
```

This makes the merchant API ergonomic (no dependency injection) at the cost of one active session at a time. This is intentional — a checkout flow is inherently sequential.

**Implication for testing:** Tests must call `Payrails.createSession()` before testing factory methods. Resetting state between tests requires re-initialising the session.

---

## UIKit architecture

All UI elements are UIKit `UIView` or `UIControl` subclasses:

- `Payrails.CardForm` — `UIStackView` subclass
- `Payrails.CardPaymentButton` — `UIButton` subclass (via `ActionButton`)
- `Payrails.StoredInstruments` — `UIView` managing a vertical `UIStackView`
- `Payrails.StoredInstrumentView` — single-row `UIView`
- `Payrails.ApplePayButton` — wraps `PKPaymentButton`
- `Payrails.PayPalButton` — custom `UIButton` wrapping PayPalCheckout SDK

There is no SwiftUI layer in the payment elements (only the debug viewer uses SwiftUI). This keeps the SDK compatible with pure UIKit apps and avoids SwiftUI state management complexity in payment-critical paths.

---

## 3DS flow

```
CardPaymentButton.pay()
  └── session.executePayment(with: .card, ...)
        └── CardPaymentHandler.makePayment()
              └── PayrailsAPI.makePayment() → pending status
                    └── session.paymentHandlerDidHandlePending()
                          └── payrailsAPI.confirmPayment(link:)
                                — polls until final status
                          └── paymentHandlerWillRequestChallengePresentation()
                                └── cardFormDelegate.onThreeDSecureChallenge()
                                      — SFSafariViewController presented
```

The `PaymentPresenter` protocol is the seam: the session calls `paymentHandlerWillRequestChallengePresentation`, which triggers `onThreeDSecureChallenge` on the delegate (which is typically the view controller). The view controller then presents the `SFSafariViewController` it receives via `presentPayment(_:)`.

---

## KMP / cross-platform notes

There are no KMP considerations at present — the iOS SDK is UIKit/Swift only. If cross-platform sharing becomes a goal, the `Domains/` folder (pure value types with no UIKit imports) is the natural candidate for extraction.

---

## External dependencies

| Dependency | Purpose | Source |
|---|---|---|
| `PayrailsCSE` | Client-side encryption of card data (Skyflow vault) | `github.com/payrails/ios-cse` |
| `PayPalCheckout` | PayPal native checkout sheet | `github.com/paypal/paypalcheckout-ios` |

Both are pulled transitively. Merchants do not need to declare them separately.
