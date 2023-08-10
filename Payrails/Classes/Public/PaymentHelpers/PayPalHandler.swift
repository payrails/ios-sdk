import Foundation
import PayPalCheckout
import PayPal

class PayPalHandler: NSObject {

    private weak var delegate: PaymentHandlerDelegate?
    private let payPalNativeClient: PayPalNativeCheckoutClient
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
        let config = CoreConfig(
            clientID: config.clientId,
            environment: environment == .dev ? .sandbox : .live
        )
        payPalNativeClient = PayPalNativeCheckoutClient(
            config: config
        )
    }
}

extension PayPalHandler: PaymentHandler {
    func makePayment(
        total: Double,
        currency: String,
        presenter: PaymentPresenter?
    ) {
        payPalNativeClient.delegate = self
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
                "savePaymentInstrument": saveInstrument
            ]
        )
    }

    func handlePendingState(with executionResult: GetExecutionResult) {
        guard let confirmLink = executionResult.links.confirm,
              let orderId = confirmLink.action?.parameters.orderId else {
            delegate?.paymentHandlerDidFail(
                handler: self,
                error: .missingData("Pending state failed due to missing OrderId"),
                type: .payPal
            )
            return
        }
        self.confirmLink = confirmLink

        Task {
            let request = PayPalNativeCheckoutRequest(orderID: orderId)
            await payPalNativeClient.start(request: request)
        }

    }
}

extension PayPalHandler: PayPalNativeCheckoutDelegate {
    func paypal(
        _ payPalClient: PayPal.PayPalNativeCheckoutClient,
        didFinishWithResult result: PayPal.PayPalNativeCheckoutResult
    ) {
        delegate?.paymentHandlerDidHandlePending(
            handler: self,
            type: .payPal,
            link: confirmLink,
            payload: [
                "orderId": result.orderID,
                "payerId": result.payerID
            ]
        )
    }

    func paypal(_ payPalClient: PayPalNativeCheckoutClient, didFinishWithError error: CoreSDKError) {
        delegate?.paymentHandlerDidFail(
            handler: self,
            error: .unknown(error: error),
            type: .payPal
        )
    }
    func paypalDidCancel(_ payPalClient: PayPalNativeCheckoutClient) {
        delegate?.paymentHandlerDidFinish(
            handler: self,
            type: .payPal,
            status: .canceled,
            payload: nil
        )
    }
    func paypalWillStart(_ payPalClient: PayPalNativeCheckoutClient) { }
}
