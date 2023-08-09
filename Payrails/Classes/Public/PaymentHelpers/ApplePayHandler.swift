import Foundation
import PassKit

class ApplePayHandler: NSObject, PaymentHandler {

    private let request = PKPaymentRequest()
    private var delegate: PaymentHandlerDelegate?

    init(
        config: PaymentCompositionOptions.ApplePayConfig,
        delegate: PaymentHandlerDelegate?
    ) {
        request.merchantIdentifier = config.parameters.merchantIdentifier
        request.supportedNetworks = [.visa, .masterCard]
        request.merchantCapabilities = .capability3DS
        request.countryCode = config.parameters.countryCode
        self.delegate = delegate
    }

    func makePayment(
        total: Double,
        currency: String,
        presenter: PaymentPresenter
    ) {
        request.currencyCode = currency
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(
              label: "Total",
              amount: NSDecimalNumber(value: total)
            )
        ]

        guard let paymentController = PKPaymentAuthorizationViewController(paymentRequest: request) else { return }
        paymentController.delegate = self
        presenter.presentPayment(paymentController)
    }
}

extension ApplePayHandler: PKPaymentAuthorizationViewControllerDelegate {
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true)
        delegate?.paymentDidFinish(handler: self, type: .applePay, status: .canceled, payload: nil)
    }

    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler paymentCompletion: @escaping (PKPaymentAuthorizationResult) -> Void) {

        guard let paymentData = try? JSONSerialization.jsonObject(with: payment.token.paymentData) else {
            paymentCompletion(.init(status: .failure, errors: nil))
            delegate?.paymentDidFinish(
                handler: self,
                type: .applePay,
                status: .error(nil),
                payload: nil
            )
            return
        }

        let payload: [String: Any?] = [
            "paymentData": paymentData,
            "paymentInstrumentName": payment.token.paymentMethod.displayName,
            "paymentNetwork" : payment.token.paymentMethod.network?.rawValue ?? "",
            "transactionIdentifier": payment.token.transactionIdentifier
        ]

        paymentCompletion(.init(status: .success, errors: nil))
        controller.dismiss(animated: true)

        delegate?.paymentDidFinish(
            handler: self,
            type: .applePay,
            status: .success,
            payload: payload
        )
    }
    
}
