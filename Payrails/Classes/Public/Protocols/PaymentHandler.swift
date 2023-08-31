protocol PaymentHandler {
    func makePayment(
        total: Double,
        currency: String,
        presenter: PaymentPresenter?
    )

    func handlePendingState(with: GetExecutionResult)
}
