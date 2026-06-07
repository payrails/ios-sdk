import Foundation
import PassKit
import Contacts

class ApplePayHandler: NSObject {

    /// Whether this handler runs a normal payment (authorize) or a tokenization
    /// (save the instrument, no payment). Chosen once when the handler is created.
    enum Mode {
        case payment
        case tokenize
    }

    private let request = PKPaymentRequest()
    private weak var delegate: PaymentHandlerDelegate?
    private let saveInstrument: Bool
    private let mode: Mode

    /// Set once the user authorizes (inside `didAuthorizePayment`). Lets `…DidFinish`
    /// tell a real pre-auth cancel from the dismissal that follows a successful
    /// payment (ONB-766).
    private var didAuthorize = false
    private var finishAfterDismissal: ((ApplePayHandler) -> Void)?

    init(
        config: PaymentOptions.ApplePayConfig,
        delegate: PaymentHandlerDelegate?,
        saveInstrument: Bool,
        mode: Mode = .payment
    ) {
        request.merchantIdentifier = config.parameters.merchantIdentifier
        request.supportedNetworks = config.parameters.supportedNetworks.paymentNetworks
        if !config.parameters.merchantCapabilities.isEmpty {
            request.merchantCapabilities = PKMerchantCapability(rawValue: config.parameters.merchantCapabilities.merchantCapabilities)
        }
        request.countryCode = config.parameters.countryCode
        self.delegate = delegate
        self.saveInstrument = saveInstrument
        self.mode = mode
    }

    /// Serializes a `PKPayment` into the exact JSON string the backend's create-instrument
    /// endpoint expects: the full `ApplePayPayment` shape
    /// `{ billingContact, shippingContact, token: { paymentData, paymentMethod, transactionIdentifier } }`.
    ///
    /// NOTE: this is a DIFFERENT shape from the flattened payload the payment/authorize path
    /// builds — do not confuse the two.
    private func makeTokenizationPaymentToken(from payment: PKPayment) -> String? {
        // `paymentData` is the encrypted-payment JSON; decode it so it nests as JSON
        // (not as an escaped string) inside `token`.
        guard let paymentDataObject = try? JSONSerialization.jsonObject(with: payment.token.paymentData) else {
            return nil
        }

        let token: [String: Any] = [
            "paymentData": paymentDataObject,
            "paymentMethod": paymentMethodDict(from: payment),
            "transactionIdentifier": payment.token.transactionIdentifier
        ]

        var root: [String: Any] = ["token": token]
        // Contacts are best-effort: include them if Apple Pay provided them. If the backend
        // turns out to require them, we expand the mapping here.
        if let billing = payment.billingContact { root["billingContact"] = contactDict(billing) }
        if let shipping = payment.shippingContact { root["shippingContact"] = contactDict(shipping) }

        guard let data = try? JSONSerialization.data(withJSONObject: root),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    /// Maps Apple Pay's `PKPaymentMethodType` to the backend's instrument `type` string, so
    /// debit / prepaid / store cards aren't all mis-reported to the backend as "credit".
    private func paymentMethodTypeString(_ type: PKPaymentMethodType) -> String {
        switch type {
        case .credit:  return "credit"
        case .debit:   return "debit"
        case .prepaid: return "prepaid"
        case .store:   return "store"
        default:       return "unknown"
        }
    }

    /// The `paymentMethod` sub-object shared by the tokenize token and the authorize payload.
    private func paymentMethodDict(from payment: PKPayment) -> [String: Any] {
        [
            "displayName": payment.token.paymentMethod.displayName ?? "",
            "network": payment.token.paymentMethod.network?.rawValue ?? "",
            "type": paymentMethodTypeString(payment.token.paymentMethod.type)
        ]
    }

    /// Converts a `PKContact` into a JSON-serializable dictionary of name, email, and postal address.
    private func contactDict(_ contact: PKContact) -> [String: Any] {
        var dict: [String: Any] = [:]
        if let given = contact.name?.givenName { dict["givenName"] = given }
        if let family = contact.name?.familyName { dict["familyName"] = family }
        if let email = contact.emailAddress { dict["emailAddress"] = email }
        if let address = contact.postalAddress {
            dict["addressLines"] = address.street.isEmpty ? [] : [address.street]
            dict["locality"] = address.city
            dict["subLocality"] = address.subLocality
            dict["administrativeArea"] = address.state
            dict["subAdministrativeArea"] = address.subAdministrativeArea
            dict["postalCode"] = address.postalCode
            dict["country"] = address.country
            dict["countryCode"] = address.isoCountryCode
        }
        return dict
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

        let paymentComposition = PaymentComposition(
            paymentMethodCode: Payrails.PaymentType.applePay.rawValue,
            integrationType: "api",
            amount: amount,
            storeInstrument: self.saveInstrument,
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
        let amountDict = ["value": amount.value, "currency": amount.currency]

        let body: [String: Any] = [
            "amount": amountDict,
            "paymentComposition": [paymentComposition],
            "returnInfo": returnInfo
        ]

        completion(.success(body))
    }

}

extension ApplePayHandler: PKPaymentAuthorizationViewControllerDelegate {
    // Per Apple's docs this is the final delegate callback of the flow and fires on every
    // outcome (cancel / success / failure / timeout). It's also the documented place to
    // dismiss the controller — so this is the single dismiss for all paths.
    func paymentAuthorizationViewControllerDidFinish(
        _ controller: PKPaymentAuthorizationViewController
    ) {
        dismiss(controller) { [weak self] in
            guard let self else { return }

            if self.didAuthorize {
                let finish = self.finishAfterDismissal
                self.finishAfterDismissal = nil
                finish?(self)
                return
            }

            // didAuthorize == false: the user dismissed the sheet before authorizing. No token or
            // payment processing has started yet, so nothing could have failed — this is a
            // cancellation, reported through the channel that matches the active flow.
            self.notifyCancellation()
        }
    }

    /// Reports a user cancellation (sheet dismissed without authorizing) to the delegate, via the
    /// terminal channel appropriate to the active flow:
    /// - `.tokenize`: resumes the awaiting async `tokenize()` by throwing `CancellationError`
    ///   (Swift's "cancelled, not an error" sentinel).
    /// - `.payment`: delivers a `.canceled` status to the payment completion handler.
    private func notifyCancellation() {
        switch mode {
        case .tokenize:
            delegate?.paymentHandlerDidFinishTokenization(handler: self, result: .failure(CancellationError()))
        case .payment:
            delegate?.paymentHandlerDidFinish(handler: self, type: .applePay, status: .canceled, payload: nil)
        }
    }

    func paymentAuthorizationViewController(
        _ controller: PKPaymentAuthorizationViewController,
        didAuthorizePayment payment: PKPayment,
        handler paymentCompletion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        didAuthorize = true

        // TOKENIZE flow: route the token to the create-instrument call and KEEP the sheet
        // open (don't call paymentCompletion yet). We complete only when tokenization returns,
        // so a failed tokenize shows as an error in the sheet instead of a false success.
        if mode == .tokenize {
            guard let paymentToken = makeTokenizationPaymentToken(from: payment) else {
                finishAfterDismissal = { handler in
                    handler.delegate?.paymentHandlerDidFinishTokenization(
                        handler: handler,
                        result: .failure(PayrailsError.invalidDataFormat)
                    )
                }
                paymentCompletion(.init(status: .failure, errors: nil))
                return
            }
            delegate?.paymentHandlerDidRequestTokenization(
                handler: self,
                paymentToken: paymentToken
            ) { [weak self] result in
                guard let self else { return }
                let tokenizationResult = result.mapError { $0 as Error }
                self.finishAfterDismissal = { handler in
                    handler.delegate?.paymentHandlerDidFinishTokenization(
                        handler: handler,
                        result: tokenizationResult
                    )
                }
                switch result {
                case .success:
                    paymentCompletion(.init(status: .success, errors: nil))
                case .failure:
                    paymentCompletion(.init(status: .failure, errors: nil))
                }
            }
            return
        }

        // PAYMENT flow: build the authorize payload, but do not notify the session until the
        // Apple Pay controller has completed its dismissal. Starting the next UIKit/network
        // phase while PassKit is still dismissing can leave the host app unable to present
        // navigation UI immediately after the sheet closes.
        guard let paymentData = try? JSONSerialization.jsonObject(with: payment.token.paymentData) else {
            finishAfterDismissal = { handler in
                handler.delegate?.paymentHandlerDidFinish(
                    handler: handler,
                    type: .applePay,
                    status: .error(nil),
                    payload: nil
                )
            }
            paymentCompletion(.init(status: .failure, errors: nil))
            return
        }

        // Create the restructured payload with paymentMethod object
        let payload: [String: Any] = [
            "paymentData": paymentData,
            "paymentMethod": paymentMethodDict(from: payment),
            "transactionIdentifier": payment.token.transactionIdentifier,
            "paymentNetwork": payment.token.paymentMethod.network?.rawValue ?? "",
            "paymentInstrumentName": payment.token.paymentMethod.displayName ?? ""
        ]

        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            finishAfterDismissal = { handler in
                handler.delegate?.paymentHandlerDidFinish(
                    handler: handler,
                    type: .applePay,
                    status: .error(nil),
                    payload: nil
                )
            }
            paymentCompletion(.init(status: .failure, errors: nil))
            return
        }

        let successPayload: [String: Any] = [
            "paymentInstrumentData": [
                "paymentToken": String(data: payloadData, encoding: String.Encoding.utf8)
            ]
        ]
        finishAfterDismissal = { handler in
            handler.delegate?.paymentHandlerDidFinish(
                handler: handler,
                type: .applePay,
                status: .success,
                payload: successPayload
            )
        }

        paymentCompletion(.init(status: .success, errors: nil))
    }

    private func dismiss(
        _ controller: PKPaymentAuthorizationViewController,
        completion: @escaping () -> Void
    ) {
        let complete = {
            if Thread.isMainThread {
                completion()
            } else {
                DispatchQueue.main.async(execute: completion)
            }
        }

        DispatchQueue.main.async {
            guard controller.presentingViewController != nil else {
                complete()
                return
            }

            controller.dismiss(animated: true) {
                complete()
            }
        }
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
