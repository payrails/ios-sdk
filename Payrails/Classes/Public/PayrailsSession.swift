import Foundation
import PassKit

public extension Payrails {
    class Session {
        private var config: SDKConfig!
        public var executionId: String?

        private var onResult: OnPayCallback?

        init(
            _ configuration: Payrails.Configuration
        ) throws {
            self.config = try parse(config: configuration)
            executionId = config.execution?.id
        }

        public func isPaymentAvailable(type: PaymentType) -> Bool {
            return config.paymentOption(for: type) != nil
        }

        public var isApplePayAvailable: Bool {
            isPaymentAvailable(type: .applePay) && PKPaymentAuthorizationViewController.canMakePayments()
        }

        private var paymentHandler: PaymentHandler?

        public func executePayment(
            with type: PaymentType,
            presenter: PaymentPresenter,
            onResult: @escaping OnPayCallback
        ) {
            self.onResult = onResult
            guard let paymentComposition = config.paymentOption(for: type) else {
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

        @available(iOS 13.0.0, *)
        public func executePayment(
            with type: PaymentType,
            presenter: PaymentPresenter
        ) async -> OnPayResult {
            let result = await withCheckedContinuation({ continuation in
                executePayment(with: type, presenter: presenter) { result in
                    continuation.resume(returning: result)
                }
            })
            return result
        }
    }
}

private extension Payrails.Session {
    func parse(config: Payrails.Configuration) throws -> SDKConfig {
        guard let data = Data(base64Encoded: config.data) else {
            throw(PayrailsError.invalidDataFormat)
        }
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        return try jsonDecoder.decode(SDKConfig.self, from: data)
    }
}

extension Payrails.Session: PaymentHandlerDelegate {
    func paymentDidFinish(
        handler: PaymentHandler,
        type: Payrails.PaymentType,
        status: PaymentHandlerStatus,
        payload: [String : Any?]?
    ) {
        switch status {
        case .canceled:
            onResult?(.cancelledByUser)
        case .success:
            onResult?(.success)
        case let .error(error):
            onResult?(.error(PayrailsError.unknown(error: error ?? PayrailsError.invalidDataFormat)))
        }
        paymentHandler = nil
        onResult = nil
    }
}
