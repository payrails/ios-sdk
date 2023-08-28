import Foundation
import PassKit

public extension Payrails {
    class Session {
        private var config: SDKConfig!
        private var payrailsAPI: PayrailsAPI!
        private let option: Payrails.Options
        public var executionId: String?

        private var onResult: OnPayCallback?
        private var paymentHandler: PaymentHandler?
        private var currentTask: Task<Void, Error>?

        public private(set) var isPaymentInProgress = false {
            didSet {
                payrailsAPI.isRunning = isPaymentInProgress
            }
        }

        init(
            _ configuration: Payrails.Configuration
        ) throws {
            self.option = configuration.option
            self.config = try parse(config: configuration)
            self.payrailsAPI = PayrailsAPI(config: config)
            executionId = config.execution?.id
        }

        public func isPaymentAvailable(type: PaymentType) -> Bool {
            return config.paymentOption(for: type) != nil
        }

        public var isApplePayAvailable: Bool {
            return config.paymentOption(for: .applePay) != nil
        }

        public var storedInstruments: [StoredInstrument] {
            guard let paymentInstruments = config.paymentOption(for: .payPal, extra: {
                guard let paymentInstruments = $0.paymentInstruments else { return false }
                switch paymentInstruments {
                case .paypal:
                    return true
                }
            })?.paymentInstruments else {
                return []
            }
            switch paymentInstruments {
            case let .paypal(intruments):
                return intruments
                    .filter { $0.status == "enabled" }
            }
        }

        public func executePayment(
            withStoredInstrument instrument: StoredInstrument,
            presenter: PaymentPresenter?,
            onResult: @escaping OnPayCallback
        ) {
            //weak var presenter = presenter
            isPaymentInProgress = true
            self.onResult = onResult

            guard prepareHandler(
                for: instrument.type,
                saveInstrument: false
            ) else {
                return
            }

            currentTask = Task { [weak self] in
                guard let strongSelf = self else { return }
                let body = [
                    "paymentInstrumentId": instrument.id,
                    "integrationType": "api",
                    "paymentMethodCode": instrument.type.rawValue
                ]
                do {
                    let paymentStatus = try await strongSelf.payrailsAPI.makePayment(
                        type: instrument.type,
                        payload: body
                    )
                    strongSelf.handle(paymentStatus: paymentStatus)
                } catch {
                    strongSelf.handle(error: error)
                }
            }
        }

        public func executePayment(
            with type: PaymentType,
            saveInstrument: Bool = false,
            presenter: PaymentPresenter?,
            onResult: @escaping OnPayCallback
        ) {
            weak var presenter = presenter
            isPaymentInProgress = true
            self.onResult = onResult

            guard prepareHandler(
                for: type,
                saveInstrument: saveInstrument
            ),
                let paymentHandler else { return }
            paymentHandler.makePayment(
                total: Double(config.amount.value) ?? 0,
                currency: config.amount.currency,
                presenter: presenter
            )
        }

        public func cancelPayment() {
            isPaymentInProgress = false
            currentTask?.cancel()
            currentTask = nil
        }

        private func prepareHandler(
            for type: PaymentType,
            saveInstrument: Bool
        ) -> Bool {
            guard let paymentComposition = config.paymentOption(for: type) else {
                isPaymentInProgress = false
                onResult?(.error(.unsupportedPayment(type: type)))
                return false
            }

            switch type {
            case .payPal:
                switch paymentComposition.config {
                case let .paypal(payPalConfig):
                    let payPalHandler = PayPalHandler(
                        config: payPalConfig,
                        delegate: self,
                        saveInstrument: saveInstrument,
                        environment: option.env
                    )
                    self.paymentHandler = payPalHandler
                default:
                    onResult?(.error(.incorrectPaymentSetup(type: type)))
                    return false
                }
            case .applePay:
                switch paymentComposition.config {
                case let .applePay(applePayConfig):
                    let applePayHandler = ApplePayHandler(
                        config: applePayConfig,
                        delegate: self
                    )
                    self.paymentHandler = applePayHandler
                default:
                    isPaymentInProgress = false
                    onResult?(.error(.incorrectPaymentSetup(type: type)))
                    return false
                }
            }
            return true
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
            isPaymentInProgress = false
            onResult?(.cancelledByUser)
        case .success:
            currentTask = Task { [weak self] in
                guard let strongSelf = self else { return }
                var body: [String: Any] = [
                    "integrationType": "api",
                    "paymentMethodCode": type.rawValue
                ]
                if let payload {
                    payload.forEach { key, value in
                        body[key] = value
                    }
                }
                do {
                    let paymentStatus = try await strongSelf.payrailsAPI.makePayment(
                        type: type,
                        payload: body
                    )
                    strongSelf.handle(paymentStatus: paymentStatus)
                } catch {
                    strongSelf.handle(error: error)
                }
            }
        case let .error(error):
            isPaymentInProgress = false
            onResult?(.error(PayrailsError.unknown(error: error ?? PayrailsError.invalidDataFormat)))
            onResult = nil
            paymentHandler = nil
        }
    }

    func paymentHandlerDidFail(
        handler: PaymentHandler,
        error: PayrailsError,
        type: Payrails.PaymentType
    ) {
        isPaymentInProgress = false
        onResult?(.error(error))
        paymentHandler = nil
    }

    func paymentHandlerDidHandlePending(
        handler: PaymentHandler,
        type: Payrails.PaymentType,
        link: Link?,
        payload: [String: Any]?
    ) {
        guard let link else {
            isPaymentInProgress = false
            onResult?(.error(.missingData("Link response is missing")))
            paymentHandler = nil
            return
        }
        currentTask = Task { [weak self] in
            guard let strongSelf = self else { return }
            do {
                let paymentStatus = try await payrailsAPI.confirmPayment(
                    link: link,
                    payload: payload
                )
                strongSelf.handle(paymentStatus: paymentStatus)
            } catch {
                strongSelf.handle(error: error)
            }
        }
    }

    private func handle(paymentStatus: PayrailsAPI.PaymentStatus) {
        switch paymentStatus {
        case .failed:
            onResult?(.failure)
        case .success:
            onResult?(.success)
        case let .pending(executionResult):
            paymentHandler?.handlePendingState(with: executionResult)
            return
        }
        isPaymentInProgress = false
        onResult = nil
        paymentHandler = nil
    }

    private func handle(error: Error) {
        if let payrailsError = error as? PayrailsError {
            switch payrailsError {
            case .authenticationError:
                onResult?(.authorizationFailed)
            default:
                onResult?(.error(payrailsError))
            }
        } else {
            onResult?(.error(PayrailsError.unknown(error: error)))
        }
        isPaymentInProgress = false
        onResult = nil
        paymentHandler = nil
    }
}

public extension Payrails.Session {
    func executePayment(
        with type: Payrails.PaymentType,
        saveInstrument: Bool = false,
        presenter: PaymentPresenter?
    ) async -> OnPayResult {
        let result = await withCheckedContinuation({ continuation in
            executePayment(
                with: type,
                saveInstrument: saveInstrument,
                presenter: presenter
            ) { result in
                continuation.resume(returning: result)
            }
        })
        return result
    }

    func executePayment(
        withStoredInstrument instrument: StoredInstrument,
        presenter: PaymentPresenter?
    ) async -> OnPayResult {
        let result = await withCheckedContinuation({ continuation in
            executePayment(
                withStoredInstrument: instrument,
                presenter: presenter
            ) { result in
                continuation.resume(returning: result)
            }
        })
        return result
    }
}
