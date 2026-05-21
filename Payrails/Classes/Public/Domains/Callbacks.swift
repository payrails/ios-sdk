import Foundation

public typealias OnInitCallback = ((Result<Payrails.Session, PayrailsError>) -> Void)
public typealias OnPayCallback = ((OnPayResult) -> Void)

public enum OnPayResult {
    case success, authorizationFailed, failure, error(PayrailsError), cancelledByUser
}

/// Discriminator passed to `onAuthorizeFailed(_:reason:)` so merchants can react differently
/// to issuer-decline vs user-cancel vs network/SDK error vs 3DS authentication failure.
///
/// Mirrors the Web SDK's `AuthorizationFailureReasons` enum 1:1 — see
/// `web-sdk/packages/web-sdk/src/sdk/components/card-payment-button/index.ts`.
public enum AuthorizeFailureReason {
    /// Input validation failed before the request reached the backend
    /// (e.g. the card form rejected the submission). Reserved for future use; not currently
    /// emitted by the SDK but defined here for cross-platform parity with Web.
    case validationFailed

    /// The authorization was rejected by the issuer / PSP (declined, fraud-blocked, etc.).
    /// The associated `PayrailsError`, when present, carries any backend-provided detail.
    case authorizationError(PayrailsError?)

    /// 3D Secure authentication itself failed (separate from issuer decline). Typically
    /// surfaces when the SDK observes a `PayrailsError.authenticationError`.
    case authenticationError(PayrailsError?)

    /// The user intentionally abandoned the flow — e.g. swiped the 3DS challenge sheet
    /// away. No associated error.
    case userCancelled

    /// Network failure, SDK bug, or any other unexpected error not covered above.
    case unknownError(PayrailsError?)
}
