import Foundation

public typealias OnInitCallback = ((Result<Payrails.Session, PayrailsError>) -> Void)
public typealias OnPayCallback = ((OnPayResult) -> Void)

/// Closure the merchant provides at `Payrails.createSession` time. The SDK invokes it
/// when it detects the current Payrails execution is no longer reusable — most commonly
/// when the user abandoned 3DS and the execution is stuck in `authorizePending`.
///
/// The merchant fetches a fresh init payload from their backend and calls `completion`
/// with the new `InitData`. The SDK then swaps its internal config in place so the next
/// payment attempt works against the fresh execution — the merchant's existing
/// `Session` reference and any cached buttons / forms keep working unchanged.
///
///     let session = try await Payrails.createSession(
///         with: configuration,
///         onSessionExpired: { completion in
///             myBackend.fetchPayrailsInit { result in
///                 switch result {
///                 case let .success(initData):
///                     completion(.success(initData))
///                 case let .failure(error):
///                     completion(.failure(error))
///                 }
///             }
///         }
///     )
///
/// If the closure is omitted, the SDK has no way to refresh itself. The next payment
/// attempt against the poisoned Session will fail with whatever the dead execution
/// emits (typically `.authorizationError(message: "Authorization failed")`). The SDK
/// logs a warning in this case.
public typealias SessionExpiredHandler = (
    @escaping (Result<Payrails.InitData, Error>) -> Void
) -> Void

/// Optional gate the merchant provides at `Payrails.createSession` time. The SDK invokes it once
/// per payment attempt, **before** it sends the authorization request and before any provider UI
/// (wallet sheet, PayPal sheet, redirect) is presented, then waits for the answer.
///
/// Call `completion(.proceed)` to let the attempt continue, or `completion(.refuse())` to stop it.
/// On a refusal no network request is made, the initiating button returns to idle, and the
/// merchant's delegate receives `onAuthorizeFailed(_:failure:)` with code
/// `AuthorizationFailureReason.validationFailed` — never a decline.
///
/// This is what makes a merchant-side pre-payment check possible: revalidating a voucher, wallet
/// balance or loyalty points at the moment the customer commits, rather than when the button was
/// drawn.
///
///     let session = try await Payrails.createSession(
///         with: configuration,
///         onSessionExpired: { completion in /* … */ },
///         onRequestStart: { context, completion in
///             guard context.paymentMethodCode == "payPal" else {
///                 completion(.proceed)   // don't gate anything else
///                 return
///             }
///             myBackend.validatePrePayment(executionId: context.executionId) { result in
///                 switch result {
///                 case .valid:
///                     completion(.proceed)
///                 case .expired(let reason):
///                     completion(.refuse(message: reason))   // e.g. "Your voucher expired."
///                 }
///             }
///         }
///     )
///
/// The gate fires for every payment method, so a handler that forgets to `completion(.proceed)` on
/// the branches it doesn't care about will block those payments.
///
/// **Timeouts.** The SDK waits at most 10 seconds. If `completion` has not been called by then the
/// attempt is stopped and a warning is logged, so a slow or unreachable merchant endpoint can never
/// leave the button spinning indefinitely. Calling `completion` more than once is safe: the first
/// answer wins and later calls are ignored.
///
/// Omitting the handler leaves the payment flow exactly as it was — the SDK skips the gate entirely
/// rather than taking an asynchronous detour.
public typealias RequestStartHandler = (
    Payrails.RequestStartContext,
    @escaping (Payrails.RequestStartDecision) -> Void
) -> Void

public extension Payrails {
    /// A `RequestStartHandler`'s verdict on one payment attempt.
    ///
    /// An enum rather than a `Bool` so that a refusal can carry its own reason. The merchant knows
    /// why they refused — "your voucher expired", "the basket changed" — and only they can phrase
    /// it for the customer; a bare `false` would leave the SDK substituting a generic string and
    /// the merchant correlating the real reason out of band by `executionId`.
    enum RequestStartDecision {
        /// Continue with the payment.
        case proceed

        /// Stop the payment before authorization.
        ///
        /// `message`, when given, becomes `AuthorizationFailure.message` on the
        /// `.validationFailed` delivered to the merchant's delegate, so it travels to the same
        /// place the merchant already reads failure text from. It is passed through verbatim and is
        /// not displayed by the SDK — presenting it is the merchant's call. Pass `nil` (or call
        /// `.refuse()`) to get a generic SDK description instead.
        case refuse(message: String?)

        /// Refuse without a reason, leaving the SDK's generic description in place.
        public static func refuse() -> RequestStartDecision { .refuse(message: nil) }
    }
}

/// The result type emitted by the low-level `OnPayCallback` API.
///
/// **Audience.** Most merchants integrate via the higher-level **delegate-driven button
/// API** (`Payrails.CardPaymentButton`, `Payrails.CardPaymentForm`, etc.) and never
/// observe `OnPayResult` directly. The buttons translate each case into the appropriate
/// delegate method. `OnPayResult` is the lower layer used by callers of
/// `session.executePayment(..., onResult:)` and as the internal vocabulary between
/// `Session` and the buttons.
///
/// **Mapping to delegate calls** (performed by each button's `handlePaymentResult`):
///
///     OnPayResult                            delegate call(s)
///     ────────────────────────────────────── ───────────────────────────────────────────────
///     .success                               onAuthorizeSuccess(self)
///     .authorizationFailed(failure)          onAuthorizeFailed(self, failure: failure)
///     .pending                               onAuthorizePending(self)
public enum OnPayResult {
    case success
    /// The payment did not authorize. The associated `AuthorizationFailure` carries the
    /// discriminating `code` (issuer/3DS decline, auth/token error, user cancel, or
    /// unexpected error), a human-readable `message`, and the underlying `rawError` when one
    /// exists. Mirrors the Web SDK's `onFailed(action, { code, message, rawError })`.
    case authorizationFailed(AuthorizationFailure)
    /// The Payrails execution is in pending state on the backend with no action for the SDK
    /// to perform — the backend returned `authorizePending` and `actionRequired` was nil.
    /// Surfaced to the merchant via `onAuthorizePending`. No session refresh is triggered:
    /// the execution is still live and may settle later.
    case pending
}

/// Tokenize outcome — `.success` carries the saved instrument, `.cancelled` is the user dismissing
/// the sheet (not a thrown `CancellationError`), and `.failed` carries the error. The callback-based
/// `tokenize(_:options:onSuccess:onFailed:onCancelled:)` uses this to map a thrown error onto the
/// matching outcome closure; the async `tokenize` returns / throws directly.
enum OnTokenizeResult {
    case success(SaveInstrumentResponse)
    case cancelled
    case failed(PayrailsError)
}

extension OnTokenizeResult {
    /// Maps a thrown tokenize error to the matching non-success case: a `CancellationError`
    /// (the user dismissed the sheet) becomes `.cancelled`; anything else becomes `.failed`,
    /// with non-`PayrailsError` errors wrapped in `.unknown(error:)`.
    init(failure error: Error) {
        if error is CancellationError {
            self = .cancelled
        } else {
            self = .failed(error as? PayrailsError ?? .unknown(error: error))
        }
    }
}

/// Discriminating code for an authorization failure. Raw values match the Web SDK's
/// `AuthorizationFailureReasons` string constants so both SDKs report identical codes.
///
/// Note that client-side *input* validation still never reaches this path — the button
/// early-returns on an invalid form instead of emitting a failure. `validationFailed` is reserved
/// for a merchant's own `RequestStartHandler` deciding the payment must not proceed.
public enum AuthorizationFailureReason: String {
    /// The authorization was rejected by the backend — issuer declined, 3DS rejected, fraud
    /// blocked, etc. The accompanying `message` carries the backend detail
    /// (`errors[0].reason.result`).
    case authorizationError = "AUTHORIZATION_ERROR"

    /// The session token was rejected (HTTP 401 / 403). The merchant must re-initialise the
    /// session; the SDK also fires its `onSessionExpired` refresh in the background.
    case authenticationError = "AUTHENTICATION_ERROR"

    /// The user intentionally abandoned the flow — e.g. swiped the 3DS challenge sheet away,
    /// or the issuer redirected to the cancel URL.
    case userCancelled = "USER_CANCELLED"

    /// Network failure, decode error, encryption failure, polling timeout, or any other
    /// unexpected error. The SDK never invents an `authorizationError`; anything it cannot
    /// attribute to a backend authorization decision lands here, with `rawError` attached.
    case unknownError = "UNKNOWN_ERROR"

    /// The merchant's `RequestStartHandler` stopped the payment before it started — it answered
    /// `false`, or it never answered within the SDK's timeout. No authorization request was sent,
    /// so this is explicitly *not* a decline and should not be reported to the customer as one.
    case validationFailed = "VALIDATION_FAILED"
}

/// The payload passed to `onAuthorizeFailed(_:failure:)` on every card-family delegate and
/// carried inside `OnPayResult.authorizationFailed(_:)`.
///
/// Flat `{ code, message, rawError }` shape, matching the Web SDK's `onFailed` payload.
/// Construct via the static helpers (`.authorizationError(message:)`, `.userCancelled`,
/// `.authenticationError`, `.unknownError(_:)`) so call sites stay terse, or via the
/// memberwise initializer when a custom message is needed.
public struct AuthorizationFailure {
    public let code: AuthorizationFailureReason
    public let message: String
    public let rawError: Error?

    public init(code: AuthorizationFailureReason, message: String, rawError: Error? = nil) {
        self.code = code
        self.message = message
        self.rawError = rawError
    }
}

public extension AuthorizationFailure {
    /// Backend-rejected authorization. `message` is the backend detail
    /// (`errors[0].reason.result`), with a generic fallback supplied by the caller.
    static func authorizationError(message: String) -> AuthorizationFailure {
        AuthorizationFailure(code: .authorizationError, message: message, rawError: nil)
    }

    /// Session token expired / rejected (HTTP 401 / 403).
    static var authenticationError: AuthorizationFailure {
        AuthorizationFailure(
            code: .authenticationError,
            message: "Authentication failed: the session token has expired or is invalid.",
            rawError: nil
        )
    }

    /// User abandoned the flow (swiped the 3DS sheet away, or issuer hit the cancel URL).
    static var userCancelled: AuthorizationFailure {
        AuthorizationFailure(code: .userCancelled, message: "User abandoned the flow.", rawError: nil)
    }

    /// The merchant's `RequestStartHandler` refused the attempt before authorization started.
    ///
    /// `message` is the merchant's own reason from `.refuse(message:)`, when they gave one. A
    /// silent or throwing handler gets the generic description instead: the SDK's diagnostics for
    /// those cases are logged, not surfaced, since they describe an integration fault and are not
    /// phrased for a customer.
    static func validationFailed(message: String? = nil) -> AuthorizationFailure {
        AuthorizationFailure(
            code: .validationFailed,
            message: message
                ?? "The payment was blocked before authorization by the onRequestStart handler.",
            rawError: nil
        )
    }

    /// Unexpected error. `message` is derived from the supplied error when available; the
    /// error itself is preserved on `rawError`.
    static func unknownError(_ error: PayrailsError?) -> AuthorizationFailure {
        AuthorizationFailure(
            code: .unknownError,
            message: error?.errorDescription ?? "An unexpected error occurred.",
            rawError: error
        )
    }
}
