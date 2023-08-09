protocol PaymentHandlerDelegate {
    func paymentDidFinish(
        handler: PaymentHandler,
        type: Payrails.PaymentType,
        status: PaymentHandlerStatus,
        payload: [String: Any?]?
    )
}

enum PaymentHandlerStatus {
    case canceled, success, error(Error?)
}
