import Foundation
import PayPalCheckout

class PayPalHandler: NSObject {

    private weak var delegate: PaymentHandlerDelegate?
    private let paypalConfig: PaymentCompositionOptions.PayPalConfig
    private var confirmLink: Link?
    private let saveInstrument: Bool

    init(
        config: PaymentCompositionOptions.PayPalConfig,
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

    func handlePendingState(with executionResult: GetExecutionResult) {
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

        Checkout.setOnErrorCallback { [weak self] paypalError in
            guard let self else { return }
            self.delegate?.paymentHandlerDidFail(
                handler: self,
                error: .unknown(error: paypalError.error),
                type: .payPal
            )
        }

        DispatchQueue.main.async {
            Checkout.showsExitAlert = false
            Checkout.start()
        }
    }
}
