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
        internal var cardSession: CardSession?

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
            if isPaymentAvailable(type: .card),
                  let vaultId = config.vaultConfiguration?.vaultId,
                  let vaultUrl = config.vaultConfiguration?.vaultUrl,
                  let token = config.vaultConfiguration?.token,
               let tableName = config.vaultConfiguration?.cardTableName {
                self.cardSession = CardSession(
                    vaultId: vaultId,
                    vaultUrl: vaultUrl,
                    token: token,
                    tableName: tableName,
                    delegate: self
                )
            }

            executionId = config.execution?.id
        }

        public func isPaymentAvailable(type: PaymentType) -> Bool {
            return config.paymentOption(for: type) != nil
        }

        public var isApplePayAvailable: Bool {
            return config.paymentOption(for: .applePay) != nil
        }

        public func storedInstruments(for type: Payrails.PaymentType) -> [StoredInstrument] {
            guard let paymentInstruments = config.paymentOption(for: type, extra: {
                guard let paymentInstruments = $0.paymentInstruments else { return false }
                switch paymentInstruments {
                case .paypal, .card:
                    return true
                }
            })?.paymentInstruments else {
                return []
            }
            switch paymentInstruments {
            case let .paypal(intruments):
                return intruments
                    .filter { $0.status == "enabled" }
            case let .card(intruments):
                return intruments
                    .filter { $0.status == "enabled" }
            }
        }

        @available(*, deprecated)
        public var storedInstruments: [StoredInstrument] {
            storedInstruments(for: .payPal)
        }

        public func executePayment(
            withStoredInstrument instrument: StoredInstrument,
            presenter: PaymentPresenter? = nil,
            onResult: @escaping OnPayCallback
        ) {
            isPaymentInProgress = true
            self.onResult = onResult

            guard prepareHandler(
                for: instrument.type,
                saveInstrument: false,
                presenter: presenter
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
            presenter: PaymentPresenter? = nil,
            onResult: @escaping OnPayCallback
        ) {
            weak var presenter = presenter
            isPaymentInProgress = true
            self.onResult = onResult

            guard prepareHandler(
                for: type,
                saveInstrument: saveInstrument,
                presenter: presenter
            ),
                  let paymentHandler else { return }
            if type == .card {
                DispatchQueue.main.async {
                    self.cardSession?.collect()
                }
            } else {
                paymentHandler.makePayment(
                    total: Double(config.amount.value) ?? 0,
                    currency: config.amount.currency,
                    presenter: presenter
                )
            }
        }

        public func cancelPayment() {
            isPaymentInProgress = false
            currentTask?.cancel()
            currentTask = nil
        }

        public func buildCardView(
            with config: CardFormConfig = CardFormConfig.defaultConfig
        ) -> UIView? {
            cardSession?.buildCardView(with: config)
        }

        public func buildCardFields(
            with config: CardFormConfig = CardFormConfig.defaultConfig
        ) -> [CardField]? {
            cardSession?.buildCardFields(with: config)
        }

        public func buildDropInView(
            with formConfig: CardFormConfig? = nil,
            presenter: PaymentPresenter? = nil,
            onResult: @escaping OnPayCallback
        ) -> DropInView {
            let view = DropInView(
                with: config,
                session: self,
                formConfig: formConfig ?? CardFormConfig.dropInConfig
            )
            view.onPay = { [weak self] item in
                guard let self else { return }
                switch item {
                case let .stored(element):
                    self.executePayment(
                        withStoredInstrument: element,
                        presenter: presenter
                    ) { [weak view] result in
                        DispatchQueue.main.async {
                            view?.hideLoading()
                            onResult(result)
                        }
                    }
                case let .new(type, saveInstrument):
                    self.executePayment(
                        with: type,
                        saveInstrument: saveInstrument,
                        presenter: presenter
                    ) { [weak view] result in
                        DispatchQueue.main.async {
                            view?.hideLoading()
                            onResult(result)
                        }
                    }
                }
            }
            return view
        }

        private func prepareHandler(
            for type: PaymentType,
            saveInstrument: Bool,
            presenter: PaymentPresenter?
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
            case .card:
                let cardPaymentHandler = CardPaymentHandler(
                    delegate: self,
                    saveInstrument: saveInstrument,
                    presenter: presenter
                )
                self.paymentHandler = cardPaymentHandler
                return true
            }
            return true
        }
    }
}

private extension Payrails.Session {
    func parse(config: Payrails.Configuration) throws -> SDKConfig {
        guard let data = Data(base64Encoded: config.initData.data) else {
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
        if type == .card {
            onResult?(.success)
            return
        }

        guard let link else {
            isPaymentInProgress = false
            onResult?(.error(.missingData("Link response is missing")))
            paymentHandler = nil
            return
        }
        currentTask = Task { [weak self] in
            guard let strongSelf = self else { return }
            do {
                let paymentStatus = try await strongSelf.payrailsAPI.confirmPayment(
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
    @MainActor
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

    @MainActor
    func executePayment(
        withStoredInstrument instrument: StoredInstrument,
        presenter: PaymentPresenter? = nil
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

extension Payrails.Session: CardSessionDelegate {
    func cardSessionConfirmed(with response: Any) {
        guard let cardPaymentHandler = paymentHandler as? CardPaymentHandler else {
            return
        }
        cardPaymentHandler.set(response: response)
        cardPaymentHandler.makePayment(
            total: Double(config.amount.value) ?? 0,
            currency: config.amount.currency,
            presenter: nil
        )
    }

    func cardSessionFailed(with error: Any) {
        onResult?(.error(PayrailsError.invalidCardData))
        isPaymentInProgress = false
        onResult = nil
        paymentHandler = nil
    }
}
