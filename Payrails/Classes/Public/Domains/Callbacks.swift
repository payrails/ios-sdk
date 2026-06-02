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

/// Discriminating code for an authorization failure. Raw values match the Web SDK's
/// `AuthorizationFailureReasons` string constants so both SDKs report identical codes.
///
/// Web's `VALIDATION_FAILED` is intentionally absent: input validation happens client-side
/// before submission and never reaches this path (the button early-returns on an invalid
/// form instead of emitting a failure).
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
