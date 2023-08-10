protocol PaymentHandlerDelegate {
    func paymentHandlerDidFinish(
        handler: PaymentHandler,
        type: Payrails.PaymentType,
        status: PaymentHandlerStatus,
        payload: [String: Any]?
    )
}

enum PaymentHandlerStatus {
    case canceled, success, error(Error?)
}
