protocol PaymentHandler {
    func makePayment(
        total: Double,
        currency: String,
        presenter: PaymentPresenter?
    )

    func handlePendingState(with: GetExecutionResult)

    func processSuccessPayload(
        payload: [String: Any]?,
        amount: Amount,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    )

    /// Dismiss any user-facing view this handler has presented (e.g. a 3DS WebView).
    /// Called when the session resolves the payment outcome from a source other than
    /// the presented view (e.g. background polling discovered a terminal status first).
    func dismissPresentedView()
}

extension PaymentHandler {
    func dismissPresentedView() {}
}

// Add a default implementation
// extension PaymentHandler {
//    func processSuccessPayload(
//        payload: [String: Any]?,
//        amount: Amount,
//        completion: @escaping (Result<[String: Any], Error>) -> Void
//    ) {
//        completion(.failure(PayrailsError.unsupportedPayment(type: .card)))
//    }
// }
