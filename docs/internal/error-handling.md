# Error Handling

How errors flow through the SDK — from detection to merchant callback.

---

## Error taxonomy

The SDK uses two mechanisms for surfacing problems:

| Mechanism | When | Example |
|---|---|---|
| `precondition` crash | Programming error (misuse of factory methods) | `createCardForm()` called before `createSession()` |
| `PayrailsError` | Runtime error (expected failure during payment) | Network timeout, authentication expiry, missing config |

---

## `PayrailsError` cases

```swift
public enum PayrailsError: Error, LocalizedError {
    // Auth / init
    case authenticationError        // Token expired or invalid (401 from API)
    case sdkNotInitialized          // Redundant with precondition; kept for callback paths
    case missingData(String?)       // Required field absent from init payload
    case invalidDataFormat          // Init payload could not be base64-decoded or JSON-decoded

    // Payment setup
    case invalidCardData            // Card fields invalid at submission time
    case unsupportedPayment(type: Payrails.PaymentType)   // Payment type not in init payload
    case incorrectPaymentSetup(type: Payrails.PaymentType) // Config type mismatch (e.g. ApplePay config missing)

    // Network / polling
    case pollingFailed(String)
    case failedToDerivePaymentStatus(String)
    case finalStatusNotFoundAfterLongPoll(String)
    case longPollingFailed(underlyingError: Error?)

    // Catch-all
    case unknown(error: Error?)
}
```

`PayrailsError` conforms to `LocalizedError`. Use `error.errorDescription` to get a human-readable description.

---

## Error propagation overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Error Source                             │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐    │
│  │ Factory call  │  │ PayrailsAPI  │  │  PaymentHandler    │    │
│  │ before init   │  │ network call │  │  logic error       │    │
│  └──────┬───────┘  └──────┬───────┘  └────────┬───────────┘    │
│         │                 │                    │                │
│   precondition()    PayrailsError         PayrailsError        │
│   (crash — not      or raw Error          or raw Error         │
│    catchable)             │                    │                │
│                           └────────┬───────────┘                │
│                                    ▼                            │
│                          session.handle(error:)                 │
│                                    │                            │
│                    ┌───────────────┼───────────────┐            │
│                    ▼               ▼               ▼            │
│            .authenticationError  PayrailsError   raw Error      │
│                    │               │               │            │
│                    ▼               ▼               ▼            │
│           .authorizationFailed  .error(e)   .error(.unknown)   │
│                                                                 │
│                           OnPayResult                           │
│                              │                                  │
│                              ▼                                  │
│                 CardPaymentButton.handlePaymentResult           │
│                              │                                  │
│              ┌───────────────┼───────────────┐                  │
│              ▼               ▼               ▼                  │
│         .success    .authorizationFailed  .failure/.error       │
│              │          .cancelledByUser      │                 │
│              ▼               ▼               ▼                  │
│       onAuthorizeSuccess  onAuthorizeFailed  onAuthorizeFailed  │
│                          (logged only for                       │
│                           cancelledByUser)                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## How errors propagate

### Card payment path

```
CardPaymentButton.pay()
  └── session.executePayment(with:saveInstrument:presenter:onResult:)
        ├── prepareHandler() fails → onResult(.error(.unsupportedPayment or .incorrectPaymentSetup))
        ├── invalid amount format  → onResult(.error(.invalidDataFormat))
        └── paymentHandler.makePayment()
              └── PayrailsAPI calls
                    ├── HTTP 401           → handle(error:) → onResult(.authorizationFailed)
                    ├── PayrailsError      → handle(error:) → onResult(.error(payrailsError))
                    └── any other Error    → handle(error:) → onResult(.error(.unknown(error:)))

```

### Delegate translation

`session.handle(error:)` is the central error-to-delegate translator:

```swift
private func handle(error: Error) {
    if let payrailsError = error as? PayrailsError {
        switch payrailsError {
        case .authenticationError:
            onResult?(.authorizationFailed)   // special case: auth errors → authorizationFailed
        default:
            onResult?(.error(payrailsError))
        }
    } else {
        onResult?(.error(PayrailsError.unknown(error: error)))
    }
    isPaymentInProgress = false
    onResult = nil
    paymentHandler = nil
}
```

This means `.authenticationError` is silently converted to `.authorizationFailed` at the `OnPayResult` level. Merchants see a clean "authorization failed" state rather than needing to match a specific error case.

### CardPaymentButton translation

`CardPaymentButton.handlePaymentResult(_:)` maps `OnPayResult` to delegate calls:

```swift
case .success         → delegate.onAuthorizeSuccess
case .authorizationFailed, .failure, .error → delegate.onAuthorizeFailed
case .cancelledByUser → logged only (no delegate call)
```

Note: `.failure` and `.error` both call `onAuthorizeFailed`. Merchants cannot distinguish these two at the delegate level. If you need to surface more granularity, you must change the delegate protocol and update the audit doc.

---

## 3DS error path

When a 3DS challenge is required, `CardPaymentHandler` notifies the session via `paymentHandlerWillRequestChallengePresentation`. The session notifies both `PayrailsCardPaymentFormDelegate.onThreeDSecureChallenge()` and `PayrailsCardPaymentButtonDelegate.onThreeDSecureChallenge(_:)` (via `Payrails.currentCardPaymentButton`). Errors after 3DS are handled the same way as other payment errors.

---

## Stored instrument payment

Errors follow the same path via `session.executePayment(withStoredInstrument:)` → `handle(error:)`. The only difference is there is no 3DS challenge in the current stored instrument flow.

---

## Factory errors

Factories use `precondition`. These are not catchable. They indicate integration bugs:

| Precondition | What it means |
|---|---|
| `"Payrails session must be initialized before creating a CardForm"` | `createCardForm()` called before `createSession()` |
| `"A card form must be created with createCardForm() before creating a CardPaymentButton"` | Factory order violated |
| `"Payrails session must be initialized before creating a CardPaymentButton"` | Same as above |

---

## Adding new error cases

1. Add the case to `PayrailsError` in `Domains/PayrailsError.swift`
2. Add a human-readable `errorDescription` in the extension
3. Throw or assign the new case in the relevant handler
4. Add a test that exercises the error path
5. Update `public-api-audit.md` if the case is public

---

## Best practices for merchants (from internal perspective)

Merchants are told to:

1. **Always verify on the backend.** `onAuthorizeSuccess` means the SDK received a success status, but merchants must confirm with their own backend before fulfilling the order.
2. **Re-initialize the session** if they see `.authorizationFailed` (expired token) rather than retrying the payment.
3. **Show a user-friendly error** for `.failure` and `.error` rather than the technical `errorDescription`.
