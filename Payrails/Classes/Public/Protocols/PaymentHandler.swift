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
}

// Add a default implementation
//extension PaymentHandler {
//    func processSuccessPayload(
//        payload: [String: Any]?,
//        amount: Amount,
//        completion: @escaping (Result<[String: Any], Error>) -> Void
//    ) {
//        completion(.failure(PayrailsError.unsupportedPayment(type: .card)))
//    }
//}
