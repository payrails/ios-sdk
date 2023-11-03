import Foundation

class CardPaymentHandler {

    private weak var delegate: PaymentHandlerDelegate?
    private let response: Any
    
    init(
        response: Any,
        delegate: PaymentHandlerDelegate?
    ) {
        self.response = response
        self.delegate = delegate
    }
}

extension CardPaymentHandler: PaymentHandler {
    func makePayment(
        total: Double,
        currency: String,
        presenter: PaymentPresenter?
    ) {
        delegate?.paymentHandlerDidFinish(
            handler: self,
            type: .card,
            status: .success,
            payload: [
                "paymentInstrumentData": [
                    "providerData": [ ]
                ],
                "storeInstrument": false
            ]
        )
    }

    func handlePendingState(with: GetExecutionResult) {

    }
}
