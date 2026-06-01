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
│                                    ▼                            │
│                         AuthorizationFailure                    │
│                          { code, message, rawError }            │
│                                                                 │
│                           OnPayResult                           │
│                              │                                  │
│                              ▼                                  │
│                 CardPaymentButton.handlePaymentResult           │
│                              │                                  │
│       ┌──────────────────────┼──────────────────────┐           │
│       ▼                      ▼                      ▼           │
│   .success         .authorizationFailed         .pending        │
│       │                  (failure)                  │           │
│       ▼                      ▼                      ▼           │
│  onAuthorize-       onAuthorizeFailed         onAuthorize-      │
│  Success             (failure:)               Pending           │
│                                                                 │
│ The `onSessionExpired` closure (supplied at `createSession`)    │
│ fires in parallel on any path that leaves the Payrails          │
│ execution non-terminal (pending) on the backend — typically     │
│ when the user dismissed 3DS and the confirmation-poll grace     │
│ window found no backend terminal. Backend-confirmed terminals   │
│ (success / authorization-failed / cancelled-via-URL) do NOT     │
│ trigger it — those executions are closed cleanly.               │
└─────────────────────────────────────────────────────────────────┘
```

---

## How errors propagate

### Card payment path

```
CardPaymentButton.pay()
  └── session.executePayment(with:saveInstrument:presenter:onResult:)
        ├── prepareHandler() fails → onResult(.authorizationFailed(.unknownError(.unsupportedPayment | .incorrectPaymentSetup)))
        ├── invalid amount format  → onResult(.authorizationFailed(.unknownError(.invalidDataFormat)))
        └── paymentHandler.makePayment()
              └── PayrailsAPI calls
                    ├── HTTP 401/403       → handle(error:) → onResult(.authorizationFailed(.authenticationError))
                    │                                       → refreshIfPossible()
                    ├── backend decline    → onResult(.authorizationFailed(.authorizationError(message: <backend>)))
                    ├── PayrailsError      → handle(error:) → onResult(.authorizationFailed(.unknownError(payrailsError)))
                    │                                       → refreshIfPossible() for polling timeout
                    └── any other Error    → handle(error:) → onResult(.authorizationFailed(.unknownError(error)))

```

### Delegate translation

The session funnels every failure path into `OnPayResult.authorizationFailed(AuthorizationFailure)`, where the carried struct has `.code` (discriminator), `.message` (backend detail or generic fallback), and `.rawError` (underlying error when one exists). Construction goes through static helpers on `AuthorizationFailure`:

```swift
extension AuthorizationFailure {
    static func authorizationError(message: String) -> AuthorizationFailure  // backend decline
    static var authenticationError: AuthorizationFailure                     // 401 / 403
    static var userCancelled: AuthorizationFailure                           // user abandoned flow
    static func unknownError(_ error: PayrailsError?) -> AuthorizationFailure
}
```

### CardPaymentButton translation

`CardPaymentButton.handlePaymentResult(_:)` maps `OnPayResult` cases to delegate calls:

```swift
case .success                       → delegate.onAuthorizeSuccess(self)
case .authorizationFailed(failure)  → delegate.onAuthorizeFailed(self, failure: failure)
case .pending                       → delegate.onAuthorizePending(self)

// `failure.message` for `.authorizationError` carries the backend's
// `errors[0].reason.result`, extracted in PayrailsAPI.checkExecutionStatus →
// Status.paymentStatus(with:). When the backend provides no detail it falls back
// to PayrailsAPI.genericAuthorizationFailedMessage ("Authorization failed") —
// never nil. Mirrors web-sdk's
// `confirmResult.finalState?.errors?.[0]?.reason?.result || 'Authorization Failed'`.
```

The `onSessionExpired` closure (supplied to `Payrails.createSession(with:onSessionExpired:)`) is invoked by the session — NOT the button — on any path that leaves the Payrails execution non-terminal on the backend. This is single-fire-per-poisoned-execution and decoupled from per-button delegate dispatch; merchants never wire it on a button.

`AuthorizationFailureReason` mirrors the Web SDK's `AuthorizationFailureReasons` enum 1:1 (raw values match). The same mapping is mirrored in `CardPaymentForm`, `StoredInstrumentPaymentButton`, and `GenericRedirectButton`.

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
