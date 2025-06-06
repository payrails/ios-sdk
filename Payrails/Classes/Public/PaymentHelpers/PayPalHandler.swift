import Foundation
import PayPalCheckout

class PayPalHandler: NSObject {

    private weak var delegate: PaymentHandlerDelegate?
    private let paypalConfig: PaymentOptions.PayPalConfig
    private var confirmLink: Link?
    private let saveInstrument: Bool

    init(
        config: PaymentOptions.PayPalConfig,
        delegate: PaymentHandlerDelegate?,
        saveInstrument: Bool,
        environment: Payrails.Env
    ) {
        self.delegate = delegate
        self.paypalConfig = config
        self.saveInstrument = saveInstrument
        let config = CheckoutConfig(
            clientID: config.clientId,
            environment: environment == .dev ? .sandbox : .live
        )

        Checkout.set(config: config)
    }
}

extension PayPalHandler: PaymentHandler {
    func makePayment(
        total: Double,
        currency: String,
        presenter: PaymentPresenter?
    ) {
        delegate?.paymentHandlerDidFinish(
            handler: self,
            type: .payPal,
            status: .success,
            payload: [
                "paymentInstrumentData": [
                    "providerData": [
                        "merchantId": paypalConfig.merchantId
                    ]
                ],
                "storeInstrument": saveInstrument
            ]
        )
    }

    func handlePendingState(
        with executionResult: GetExecutionResult
    ) {
        guard let confirmLink = executionResult.links.confirm else {
            delegate?.paymentHandlerDidFail(
                handler: self,
                error: .missingData("Pending state failed due to missing OrderId"),
                type: .payPal
            )
            return
        }
        self.confirmLink = confirmLink

        Checkout.setCreateOrderCallback { [weak self] createOrderActions in
            if let billingAgreementToken = confirmLink.action?.parameters.tokenId {
                createOrderActions.set(billingAgreementToken: billingAgreementToken)
            } else if let orderId = confirmLink.action?.parameters.orderId {
                createOrderActions.set(orderId: orderId)
            } else {
                guard let self else { return }
                self.delegate?.paymentHandlerDidFail(
                    handler: self,
                    error: .missingData("no OrderId or BillingAgreementToken"),
                    type: .payPal
                )
            }
        }

        Checkout.setOnApproveCallback { [weak self] approval in
            let approvalData = approval.data
            guard let self else { return }
            var payload: [String: String] = [
                "orderId": approvalData.ecToken,
                "payerId": approvalData.payerID
            ]
            if let billingToken = approvalData.billingToken,
               !billingToken.isEmpty {
                payload["tokenId"] = billingToken
            }
            self.delegate?.paymentHandlerDidHandlePending(
                handler: self,
                type: .payPal,
                link: confirmLink,
                payload: payload
            )
        }

        Checkout.setOnCancelCallback { [weak self] in
            guard let self else { return }
            self.delegate?.paymentHandlerDidFinish(
                handler: self,
                type: .payPal,
                status: .canceled,
                payload: nil
            )
        }

        // TODO: check this
        Checkout.setOnErrorCallback { _ in
//            guard let self else { return }
//            self.delegate?.paymentHandlerDidFail(
//                handler: self,
//                error: .unknown(error: paypalError.error),
//                type: .payPal
//            )
        }

        DispatchQueue.main.async {
            Checkout.showsExitAlert = false
            Checkout.start()
        }
    }
    
    func processSuccessPayload(
        payload: [String: Any]?,
        amount: Amount,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let payload = payload,
              let storeInstrument = payload["storeInstrument"] as? Bool else {
            print("❌ PayPal payload missing required keys (e.g., storeInstrument). Payload: \(String(describing: payload))")
            completion(.failure(PayrailsError.invalidDataFormat))
            return
        }

        // Create PayPal-specific payment composition
        let payPalComposition = PaymentComposition(
            paymentMethodCode: Payrails.PaymentType.payPal.rawValue,
            integrationType: "api",
            amount: amount,
            storeInstrument: storeInstrument,
            paymentInstrumentData: nil,
            enrollInstrumentToNetworkOffers: false
        )
        
        // Prepare the request body
        let returnInfo: [String: String] = [
            "success": "https://assets.payrails.io/html/payrails-success.html",
            "cancel": "https://assets.payrails.io/html/payrails-cancel.html",
            "error": "https://assets.payrails.io/html/payrails-error.html",
            "pending": "https://assets.payrails.io/html/payrails-pending.html"
        ]
        let risk = ["sessionId": "03bf5b74-d895-48d9-a871-dcd35e609db8"]
        let meta = ["risk": risk]
        let amountDict = ["value": amount.value, "currency": amount.currency]
        
        let body: [String: Any] = [
            "amount": amountDict,
            "paymentComposition": [payPalComposition],
            "returnInfo": returnInfo,
            "meta": meta
        ]
        
        completion(.success(body))
    }

}
