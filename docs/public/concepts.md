# Concepts

This page explains the mental model behind the Payrails iOS SDK so you can reason about integration decisions confidently.

---

## The three building blocks

### 1. Session

The **Session** (`Payrails.Session`) is the single source of truth for a checkout. It holds:

- The parsed init payload (amounts, payment method configurations, vault settings)
- The active execution ID
- The holder reference
- Links to backend API actions (BIN lookup, instrument management)

You create a session once per checkout by calling `Payrails.createSession(with:)`. All elements and factory methods draw their configuration from the current session — there is no need to pass it around explicitly.

```
App Backend  ──init payload──►  Payrails.createSession()  ──►  Session (ready)
```

A session does not persist across app launches. When the user starts a new checkout, create a new session.

### 2. Elements

Elements are UIKit views that the SDK manages. You obtain them via factory methods on `Payrails`:

| Factory method | Element type | Description |
|---|---|---|
| `Payrails.createCardForm()` | `Payrails.CardForm` | Card input form (number, expiry, CVV, optional name) |
| `Payrails.createCardPaymentButton(translations:)` | `Payrails.CardPaymentButton` | Submit button for card form or stored instrument |
| `Payrails.createApplePayButton(type:style:)` | `ApplePayElement` | Apple Pay button wrapping `PKPaymentButton` |
| `Payrails.createPayPalButton()` | `PaypalElement` | PayPal checkout button |
| `Payrails.createGenericRedirectButton(translations:paymentMethodCode:)` | `Payrails.GenericRedirectButton` | Button for redirect-based methods (e.g. iDEAL) |
| `Payrails.createStoredInstruments()` | `Payrails.StoredInstruments` | List of previously saved payment methods |

All elements are UIView subclasses; add them to your view hierarchy with Auto Layout or frames.

> **Note:** `Payrails.createCardPaymentButton` requires that `createCardForm` has been called first. The form and button are linked automatically.

### 3. Delegates

Delegates are protocols your view controller (or any object) conforms to in order to receive payment lifecycle events. Each element type has a corresponding delegate:

| Element | Delegate protocol |
|---|---|
| `CardPaymentButton` | `PayrailsCardPaymentButtonDelegate` |
| `ApplePayButton` | `PayrailsApplePayButtonDelegate` |
| `PayPalButton` | `PayrailsPayPalButtonDelegate` |
| `GenericRedirectButton` | `GenericRedirectPaymentButtonDelegate` |
| `StoredInstruments` | `PayrailsStoredInstrumentsDelegate` |
| `StoredInstrumentView` | `PayrailsStoredInstrumentViewDelegate` |

Assign the delegate before adding the element to the window.

---

## Payment flows

### Card payment (new card)

```
1. createCardForm()                — card fields appear
2. createCardPaymentButton()       — pay button appears
3. User fills fields, taps button
4. SDK encrypts card data (PayrailsCSE)
5. SDK calls Payrails payment API
6. ┌─ 3DS required ──► presentPayment(_:) called on PaymentPresenter
│                   ──► user completes challenge in SFSafariViewController
│                   ──► SDK polls for final status
└─ no 3DS  ──► result delivered immediately
7. delegate.onAuthorizeSuccess / onAuthorizeFailed called
```

### Stored instrument payment

```
1. createStoredInstruments() or createCardPaymentButton(storedInstrument:)
2. User selects instrument, taps button
3. SDK calls Payrails payment API with instrument ID
4. Result via delegate callback
```

### Apple Pay

```
1. createApplePayButton(type:style:)
2. User taps button
3. Apple Pay sheet presented by the SDK
4. User authorises with Face ID / Touch ID
5. SDK processes payment token
6. Result via PayrailsApplePayButtonDelegate
```

### PayPal

```
1. createPayPalButton()
2. User taps button
3. PayPal checkout web flow presented
4. SDK confirms payment and polls for status
5. Result via PayrailsPayPalButtonDelegate
```

### Generic redirect

```
1. createGenericRedirectButton(translations:paymentMethodCode:)
2. User taps button
3. Browser opens redirect URL (SFSafariViewController)
4. User completes flow on payment provider website
5. App returns to foreground — success is reported immediately
```

---

## 3D Secure

When a card payment requires a 3DS challenge, the SDK presents an `SFSafariViewController`. Your view controller must conform to `PaymentPresenter` and implement `presentPayment(_:)`:

```swift
func presentPayment(_ viewController: UIViewController) {
    present(viewController, animated: true)
}
```

The SDK handles the rest: it polls the Payrails API until a final status is received, then calls the appropriate delegate callback.

> Set `payButton.presenter = self` before the user taps the button.

---

## CardPaymentButton modes

`Payrails.CardPaymentButton` operates in two modes:

| Mode | How it's created | Behaviour on tap |
|---|---|---|
| **Card form mode** | `createCardPaymentButton(translations:)` (requires prior `createCardForm()`) | Collects and encrypts card fields, then executes payment |
| **Stored instrument mode** | `createCardPaymentButton(storedInstrument:translations:)` | Executes payment immediately with the stored instrument |

You can switch between modes at runtime using `setStoredInstrument(_:)` and `clearStoredInstrument()`.

---

## Stored instruments and `bindCardPaymentButton`

`Payrails.StoredInstruments` can be bound to a single `CardPaymentButton`:

```swift
let storedInstrumentsView = Payrails.createStoredInstruments()
let payButton = Payrails.createCardPaymentButton(translations: translations)

storedInstrumentsView.bindCardPaymentButton(payButton)
```

When a user selects an instrument from the list, the button automatically switches to stored instrument mode. When deselected, it reverts to card form mode. This pattern lets you render one card form and one pay button that handles both flows without conditional logic in your view controller.

---

## Security model

- **Card data is never exposed in plaintext.** The SDK encrypts card fields using PayrailsCSE (a Skyflow vault client) before they leave the device.
- **The Session token is short-lived.** Tokens are fetched by your backend and passed to the SDK; they are not stored persistently.
- **Logging is off by default.** The debug overlay and `Payrails.log` output are only visible when explicitly enabled. See [Troubleshooting](troubleshooting.md) for details.

---

## Element lifecycle

Elements hold a weak reference to the session. They are safe to create in `viewDidLoad` and will be deallocated with the view controller. You do not need to manually tear them down.

If the user navigates away during a payment, the in-flight `Task` is cancelled in `deinit` of `CardPaymentButton`, preventing dangling callbacks.

---

## Next steps

- [Quick Start](quick-start.md) — get to a running integration in 15 minutes
- [SDK API Reference](sdk-api-reference.md) — complete API surface
- [Styling Guide](merchant-styling-guide.md) — customise the UI
