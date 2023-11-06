import Foundation

class CardPaymentHandler {

    private weak var delegate: PaymentHandlerDelegate?
    private var response: Any?
    private let saveInstrument: Bool

    init(
        delegate: PaymentHandlerDelegate?,
        saveInstrument: Bool
    ) {
        self.delegate = delegate
        self.saveInstrument = saveInstrument
    }
}

extension CardPaymentHandler: PaymentHandler {
    func set(response: Any) {
        self.response = response
    }
    
    func makePayment(
        total: Double,
        currency: String,
        presenter: PaymentPresenter?
    ) {
        let dictionary = ((response as? [String: Any])?["records"] as? [Any])?.first as? [String: Any]
        guard let fields = dictionary?["fields"] as? [String: Any] else {
            delegate?.paymentHandlerDidFail(handler: self, error: .missingData("fields"), type: .card)
            return
        }

        var data: [String: Any] = [:]
        data["vaultToken"] = fields["skyflow_id"]
        data["card"] = [
            "numberToken": fields["card_number"],
            "securityCodeToken": fields["security_code"]
        ]

        delegate?.paymentHandlerDidFinish(
            handler: self,
            type: .card,
            status: .success,
            payload: [
                "paymentInstrumentData": data,
                "storeInstrument": saveInstrument
            ]
        )
    }

    func handlePendingState(with: GetExecutionResult) {

    }
}
