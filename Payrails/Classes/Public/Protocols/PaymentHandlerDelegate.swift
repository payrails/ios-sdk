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
}

extension PaymentHandlerDelegate {
    func paymentHandlerUserDidDismissChallenge(handler: PaymentHandler) {}
}

enum PaymentHandlerStatus {
    case canceled, success, error(Error?)
}
