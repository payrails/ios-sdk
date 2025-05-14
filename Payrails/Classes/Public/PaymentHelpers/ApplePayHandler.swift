import Foundation
import PassKit

class ApplePayHandler: NSObject {

    private let request = PKPaymentRequest()
    private weak var delegate: PaymentHandlerDelegate?

    init(
        config: PaymentOptions.ApplePayConfig,
        delegate: PaymentHandlerDelegate?
    ) {
        request.merchantIdentifier = config.parameters.merchantIdentifier
        request.supportedNetworks = config.parameters.supportedNetworks.paymentNetworks
        if !config.parameters.merchantCapabilities.isEmpty {
            request.merchantCapabilities = PKMerchantCapability(rawValue: config.parameters.merchantCapabilities.merchantCapabilities)
        }
        request.countryCode = config.parameters.countryCode
        self.delegate = delegate
    }
}

extension ApplePayHandler: PaymentHandler {
    func makePayment(
        total: Double,
        currency: String,
        presenter: PaymentPresenter?
    ) {
        request.currencyCode = currency
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(
              label: "Total",
              amount: NSDecimalNumber(value: total)
            )
        ]
        guard let paymentController = PKPaymentAuthorizationViewController(paymentRequest: request) else {
            delegate?.paymentHandlerDidFail(
                handler: self,
                error: .unknown(error: nil),
                type: .applePay
            )
            return
        }
        paymentController.delegate = self
        presenter?.presentPayment(paymentController)
    }

    func handlePendingState(with: GetExecutionResult) {}
    
    func processSuccessPayload(
        payload: [String: Any]?,
        amount: Amount,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let payload = payload,
              let paymentInstrumentData = payload["paymentInstrumentData"] else {
            Payrails.log("❌ Apple Pay payload missing required keys")
            completion(.failure(PayrailsError.invalidDataFormat))
            return
        }
        
        // Create Apple Pay-specific payment composition
        let paymentComposition = PaymentComposition(
            paymentMethodCode: Payrails.PaymentType.applePay.rawValue,
            integrationType: "api",
            amount: amount,
            storeInstrument: false,
            paymentInstrumentData: paymentInstrumentData,
            enrollInstrumentToNetworkOffers: false
        )
        
        // TODO: this should be shared and place accordingly
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
            "paymentComposition": [paymentComposition],
            "returnInfo": returnInfo,
            "meta": meta
        ]
        
        completion(.success(body))
    }

}

extension ApplePayHandler: PKPaymentAuthorizationViewControllerDelegate {
    func paymentAuthorizationViewControllerDidFinish(
        _ controller: PKPaymentAuthorizationViewController
    ) {
        controller.dismiss(animated: true)
        delegate?.paymentHandlerDidFinish(handler: self, type: .applePay, status: .canceled, payload: nil)
    }

    func paymentAuthorizationViewController(
        _ controller: PKPaymentAuthorizationViewController,
        didAuthorizePayment payment: PKPayment,
        handler paymentCompletion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        guard let paymentData = try? JSONSerialization.jsonObject(with: payment.token.paymentData) else {
            paymentCompletion(.init(status: .failure, errors: nil))
            return
        }

        // Create the restructured payload with paymentMethod object
        let payload: [String: Any] = [
            "paymentData": paymentData,
            "paymentMethod": [
                "displayName": payment.token.paymentMethod.displayName ?? "",
                "network": payment.token.paymentMethod.network?.rawValue ?? "",
                "type": "credit"
            ],
            "transactionIdentifier": payment.token.transactionIdentifier,
            "paymentNetwork": payment.token.paymentMethod.network?.rawValue ?? "",
            "paymentInstrumentName": payment.token.paymentMethod.displayName ?? ""
        ]

        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            delegate?.paymentHandlerDidFinish(
                handler: self,
                type: .applePay,
                status: .error(nil),
                payload: nil
            )
            paymentCompletion(.init(status: .failure, errors: nil))
            return
        }

        delegate?.paymentHandlerDidFinish(
            handler: self,
            type: .applePay,
            status: .success,
            payload: [
                "paymentInstrumentData": [
                    "paymentToken": String(data: payloadData, encoding: String.Encoding.utf8)
                ]
            ]
        )

        paymentCompletion(.init(status: .success, errors: nil))
        controller.dismiss(animated: true)
    }
}

private extension Array where Element == String {
    var merchantCapabilities: UInt {
        var result: UInt = 0
        forEach { element in
            switch element {
            case "supports3DS":
                result += PKMerchantCapability.capability3DS.rawValue
            case "supportsCredit":
                result += PKMerchantCapability.capabilityCredit.rawValue
            case "supportsDebit":
                result += PKMerchantCapability.capabilityDebit.rawValue
            default:
                break
            }
        }
        return result
    }
    var paymentNetworks: [PKPaymentNetwork] {
        map { element in
            switch element {
            case "AMEX":
                return PKPaymentNetwork.amex
            case "VISA":
                return PKPaymentNetwork.visa
            case "MASTERCARD":
                return PKPaymentNetwork.masterCard
            case "JCB":
                return PKPaymentNetwork.JCB
            case "INTERAC":
                return PKPaymentNetwork.interac
            case "DISCOVER":
                return PKPaymentNetwork.discover
            case "MAESTRO":
                return PKPaymentNetwork.maestro
            default:
                return PKPaymentNetwork(element)
            }
        }
    }
}
