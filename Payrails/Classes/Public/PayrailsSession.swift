import Foundation
import PassKit

public extension Payrails {
    class Session {
        private var config: SDKConfig!
        private var payrailsAPI: PayrailsAPI!
        public var executionId: String?

        private var onResult: OnPayCallback?

        init(
            _ configuration: Payrails.Configuration
        ) throws {
            self.config = try parse(config: configuration)
            self.payrailsAPI = PayrailsAPI(config: config)
            executionId = config.execution?.id
        }

        public func isPaymentAvailable(type: PaymentType) -> Bool {
            return config.paymentComposition(for: type) != nil
        }

        public var useApplePayAvailable: Bool {
            isPaymentAvailable(type: .applePay) && PKPaymentAuthorizationViewController.canMakePayments()
        }

        private var paymentHandler: PaymentHandler?

        public func submitPayment(
            with type: PaymentType,
            presenter: PaymentPresenter,
            onResult: @escaping OnPayCallback
        ) {
            self.onResult = onResult
            guard let paymentComposition = config.paymentComposition(for: type) else {
                onResult(.error(.unsupportedPayment(type: type)))
                return
            }

            switch type {
            case .card, .payPal, .other:
                onResult(.error(.unsupportedPayment(type: type)))
            case .applePay:
                switch paymentComposition.config {
                case let .applePay(applePayConfig):
                    let applePayHandler = ApplePayHandler(
                        config: applePayConfig,
                        delegate: self
                    )
                    applePayHandler.makePayment(
                        total: Double(config.amount.value) ?? 0,
                        currency: config.amount.currency,
                        presenter: presenter
                    )
                    self.paymentHandler = applePayHandler
                default:
                    onResult(.error(.incorrectPaymentSetup(type: type)))
                }
            }
        }
    }
}

private extension Payrails.Session {
    func parse(config: Payrails.Configuration) throws -> SDKConfig {
        guard let data = Data(base64Encoded: config.data) else {
            throw(PayrailsError.invalidDataFormat)
        }
        let jsonDecoder = JSONDecoder.API()
        return try jsonDecoder.decode(SDKConfig.self, from: data)
    }
}

extension Payrails.Session: PaymentHandlerDelegate {
    func paymentHandlerDidFinish(
        handler: PaymentHandler,
        type: Payrails.PaymentType,
        status: PaymentHandlerStatus,
        payload: [String: Any]?
    ) {
        switch status {
        case .canceled:
            onResult?(.cancelledByUser)
        case .success:
            var body: [String: Any] = [
                "integrationType": "api",
                "paymentMethodCode": type.rawValue,
            ]
            if let payload {
                payload.forEach { key, value in
                    body[key] = value
                }
            }
            payrailsAPI.makePayment(type: type, payload: body) { [weak self] result in
                self?.onResult?(result)
            }
        case let .error(error):
            onResult?(.error(PayrailsError.unknown(error: error ?? PayrailsError.invalidDataFormat)))
        }
        paymentHandler = nil
        onResult = nil
    }
}

@available(iOS 13.0.0, *)
public extension Payrails.Session {
    func submitPayment(
        with type: Payrails.PaymentType,
        presenter: PaymentPresenter
    ) async -> OnPayResult {
        let result = await withCheckedContinuation({ continuation in
            submitPayment(with: type, presenter: presenter) { result in
                continuation.resume(returning: result)
            }
        })
        return result
    }
}
