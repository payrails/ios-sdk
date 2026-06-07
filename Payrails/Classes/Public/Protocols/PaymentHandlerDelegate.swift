protocol PaymentHandlerDelegate: AnyObject {
    func paymentHandlerDidFinish(
        handler: PaymentHandler,
        type: Payrails.PaymentType,
        status: PaymentHandlerStatus,
        payload: [String: Any]?
    )

    func paymentHandlerDidFail(
        handler: PaymentHandler,
        error: PayrailsError,
        type: Payrails.PaymentType
    )

    func paymentHandlerDidHandlePending(
        handler: PaymentHandler,
        type: Payrails.PaymentType,
        link: Link?,
        payload: [String: Any]?
    )

    func paymentHandlerWillRequestChallengePresentation(_ handler: PaymentHandler)

    /// Fired when the user interactively dismissed a presented challenge UI (e.g. swiping
    /// down the 3DS modal). Implementations typically run a brief confirmation poll to
    /// see if the backend has actually committed a terminal status, then report cancellation
    /// if not.
    func paymentHandlerUserDidDismissChallenge(handler: PaymentHandler)

    /// Fired by a handler when the user authorized a TOKENIZATION (not a payment). The
    /// session turns `paymentToken` into a saved instrument and reports the result back via
    /// `completion`. The handler holds its Apple Pay sheet open until `completion` runs.
    func paymentHandlerDidRequestTokenization(
        handler: PaymentHandler,
        paymentToken: String,
        completion: @escaping (Result<SaveInstrumentResponse, PayrailsError>) -> Void
    )

    /// Fired once a tokenization reaches a terminal outcome, AFTER the sheet has fully dismissed.
    /// `result` carries either the saved instrument (`.success`) or the reason it ended without
    /// one (`.failure` — the user cancelled the sheet, or the token couldn't be serialized). Lets
    /// the session resume the awaiting `tokenize` call only after UIKit has completed the transition.
    func paymentHandlerDidFinishTokenization(
        handler: PaymentHandler,
        result: Result<SaveInstrumentResponse, Error>
    )
}

extension PaymentHandlerDelegate {
    func paymentHandlerUserDidDismissChallenge(handler: PaymentHandler) {}

    // Defaults keep non-tokenizing handlers unaffected; the Session overrides these.
    func paymentHandlerDidRequestTokenization(
        handler: PaymentHandler,
        paymentToken: String,
        completion: @escaping (Result<SaveInstrumentResponse, PayrailsError>) -> Void
    ) {
        completion(.failure(.unsupportedPayment(type: .applePay)))
    }

    func paymentHandlerDidFinishTokenization(
        handler: PaymentHandler,
        result: Result<SaveInstrumentResponse, Error>
    ) {}
}

enum PaymentHandlerStatus {
    case canceled, success, error(Error?)
}
