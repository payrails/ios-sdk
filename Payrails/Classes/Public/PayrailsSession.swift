import Foundation
import PassKit
import PayrailsCSE

public extension Payrails {
    class Session {
        private var config: SDKConfig!
        private var payrailsAPI: PayrailsAPI!
        private let option: Payrails.Options
        var executionId: String?

        private var onResult: OnPayCallback?
        private var paymentHandler: PaymentHandler?
        private var currentTask: Task<Void, Error>?
        private var payrailsCSE: PayrailsCSE?

        var debugConfig: SDKConfig {
            return self.config
        }

        private(set) var isPaymentInProgress = false {
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

            do {
                self.payrailsCSE = try PayrailsCSE(data: configuration.initData.data, version: configuration.initData.version)
            } catch {
                print("Failed to initialize PayrailsCSE:", error)
            }
        }

        func isPaymentAvailable(type: PaymentType) -> Bool {
            return config.paymentOption(for: type) != nil
        }

        var isApplePayAvailable: Bool {
            return config.paymentOption(for: .applePay) != nil
        }

        func isPaymentCodeAvailable(paymentMethodCode: String) -> Bool {
            return config.paymentOption(forPaymentMethodCode: paymentMethodCode) != nil
        }

        func storedInstruments(for type: Payrails.PaymentType) -> [StoredInstrument] {
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
                    .filter { Self.isStoredInstrumentRenderable($0.status) }
            case let .card(intruments):
                return intruments
                    .filter { Self.isStoredInstrumentRenderable($0.status) }
            }
        }

        /// Mirrors Android SDK's `isStoredInstrumentRenderable()`:
        /// accepts "enabled" or "created", case-insensitive.
        /// A freshly tokenized card typically arrives with status "created"
        /// before it transitions to "enabled".
        private static func isStoredInstrumentRenderable(_ status: String) -> Bool {
            switch status.lowercased() {
            case "enabled", "created": return true
            default: return false
            }
        }

        @available(*, deprecated)
        var storedInstruments: [StoredInstrument] {
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
                    "paymentMethodCode": instrument.type.rawValue,
                    "amount": [
                        "value": strongSelf.config.amount.value,
                        "currency": strongSelf.config.amount.currency
                    ],
                    "storeInstrument": false
                ]
                do {
                    print("calling make payment")
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
            paymentMethodCode: String? = nil,
            saveInstrument: Bool = false,
            presenter: PaymentPresenter? = nil,
            onResult: @escaping OnPayCallback
        ) {
            weak var presenter = presenter

            isPaymentInProgress = true
            self.onResult = onResult

            guard prepareHandler(
                for: type,
                paymentMethodCode: paymentMethodCode,
                saveInstrument: saveInstrument,
                presenter: presenter
            ),
                let paymentHandler else {
                return
            }

            guard let total = Double(config.amount.value) else {
                onResult(.error(.invalidDataFormat))
                isPaymentInProgress = false
                return
            }

            paymentHandler.makePayment(total: total, currency: config.amount.currency, presenter: presenter)
        }

        func cancelPayment() {
            isPaymentInProgress = false
            currentTask?.cancel()
            currentTask = nil
        }

        private func prepareHandler(
            for type: PaymentType,
            paymentMethodCode: String? = nil,
            saveInstrument: Bool,
            presenter: PaymentPresenter?
        ) -> Bool {
            let paymentComposition: PaymentOptions?
            if let code = paymentMethodCode {
                paymentComposition = config.paymentOption(forPaymentMethodCode: code)
            } else {
                paymentComposition = config.paymentOption(for: type)
            }

            guard let paymentComposition = paymentComposition else {
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
                        delegate: self,
                        saveInstrument: saveInstrument
                    )
                    self.paymentHandler = applePayHandler
                default:
                    isPaymentInProgress = false
                    onResult?(.error(.incorrectPaymentSetup(type: type)))
                    return false
                }
            case .card:
                guard let providerConfigId = config.vaultConfiguration?.providerConfigId,
                      !providerConfigId.isEmpty else {
                    isPaymentInProgress = false
                    onResult?(.error(.missingData("Vault configuration with providerConfigId is required for card payments.")))
                    return false
                }

                let cardPaymentHandler = CardPaymentHandler(
                    delegate: self,
                    saveInstrument: saveInstrument,
                    presenter: presenter,
                    vaultProviderConfigId: providerConfigId
                )
                self.paymentHandler = cardPaymentHandler
                return true
            case .genericRedirect:
                let handler = GenericRedirectHandler(
                    delegate: self,
                    saveInstrument: false,
                    presenter: presenter,
                    paymentOption: paymentComposition
                )
                self.paymentHandler = handler
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
        do {
            return try jsonDecoder.decode(SDKConfig.self, from: data)
        } catch let decodingError as DecodingError {
            // Print more details about the decoding error
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("Missing key: \(key.stringValue), path: \(context.codingPath)")
            case .typeMismatch(let type, let context):
                print("Type mismatch: expected \(type), path: \(context.codingPath)")
            case .valueNotFound(let type, let context):
                print("Value not found: expected \(type), path: \(context.codingPath)")
            case .dataCorrupted(let context):
                print("Data corrupted: \(context.debugDescription)")
            @unknown default:
                print("Unknown decoding error: \(decodingError)")
            }
            throw decodingError
        }
    }
}

extension Payrails.Session: PaymentHandlerDelegate {
    func paymentHandlerWillRequestChallengePresentation(_ handler: PaymentHandler) {
        guard let cardHandler = handler as? CardPaymentHandler else {
            // If it's not a CardPaymentHandler, we don't proceed with this specific delegate call.
            // This implicitly filters for card payments in this context.
            return
        }

        guard let presenter = cardHandler.presenter else {
            print("Session Warning: CardPaymentHandler's presenter is nil.")
            return
        }

        if let cardFormDelegate = presenter as? PayrailsCardPaymentFormDelegate {
            DispatchQueue.main.async {
                cardFormDelegate.onThreeDSecureChallenge()
            }
        }

        // Notify button-based delegate (PayrailsCardPaymentButtonDelegate)
        if let button = Payrails.currentCardPaymentButton {
            DispatchQueue.main.async {
                button.delegate?.onThreeDSecureChallenge(button)
            }
        }
    }

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
            handler.processSuccessPayload(
                payload: payload,
                amount: self.config.amount
            ) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let body):
                    self.currentTask = Task {
                        do {
                            let paymentStatus = try await self.payrailsAPI.makePayment(
                                type: type,
                                payload: body
                            )
                            self.handle(paymentStatus: paymentStatus)
                        } catch {
                            self.handle(error: error)
                        }
                    }

                case .failure(let error):
                    if let payrailsError = error as? PayrailsError {
                        self.handle(error: payrailsError)
                    } else {
                        self.handle(error: PayrailsError.unknown(error: error))
                    }
                }
            }

        case let .error(error):
            isPaymentInProgress = false
            let finalError = error ?? PayrailsError.unknown(error: nil)
            onResult?(.error(finalError as! PayrailsError))
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
        if type == .genericRedirect {
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
                let paymentStatus: PayrailsAPI.PaymentStatus
                if type == .payPal {
                    // Use retry logic specifically for PayPal
                    paymentStatus = try await strongSelf.payrailsAPI.confirmPaymentWithRetry(
                        link: link,
                        payload: payload,
                        maxRetries: 2
                    )
                } else {
                    paymentStatus = try await strongSelf.payrailsAPI.confirmPayment(
                        link: link,
                        payload: nil,
                        type: .card
                    )
                }

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

        currentTask?.cancel()
        currentTask = nil
        isPaymentInProgress = false
        onResult = nil
        paymentHandler = nil
    }

    private func handle(error: Error) {
        Payrails.log("Call handle payment withn error")
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
        paymentMethodCode: String? = nil,
        saveInstrument: Bool = false,
        presenter: PaymentPresenter?
    ) async -> OnPayResult {
        let result = await withCheckedContinuation({ continuation in
            executePayment(
                with: type,
                paymentMethodCode: paymentMethodCode,
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

extension Payrails.Session {
    func getCSEInstance() -> PayrailsCSE? {
        return payrailsCSE
    }
}

extension Payrails.Session {
    func update(_ options: UpdateOptions) {
        if let amount = options.amount {
            config.amount = Amount(value: amount.value, currency: amount.currency)
        }
    }
}

extension Payrails.Session {
    func getSDKConfiguration() -> PublicSDKConfig? {
        guard let config = self.config else { return nil }
        return PublicSDKConfig(from: config)
    }

    func deleteInstrument(instrumentId: String) async throws -> DeleteInstrumentResponse {
        return try await payrailsAPI.deleteInstrument(instrumentId: instrumentId)
    }

    func updateInstrument(instrumentId: String, body: UpdateInstrumentBody) async throws -> UpdateInstrumentResponse {
        return try await payrailsAPI.updateInstrument(instrumentId: instrumentId, body: body)
    }

    func tokenize(encryptedData: String, options: TokenizeOptions) async throws -> SaveInstrumentResponse {
        guard let providerConfigId = config?.vaultConfiguration?.providerConfigId else {
            throw PayrailsError.missingData("Vault configuration with providerConfigId is required for tokenization.")
        }

        guard let holderReference = config?.holderReference else {
            throw PayrailsError.missingData("holderReference is required for tokenization.")
        }

        let body = SaveInstrumentBody(
            holderReference: holderReference,
            paymentMethod: "card",
            storeInstrument: options.storeInstrument,
            futureUsage: options.futureUsage.rawValue,
            data: SaveInstrumentBodyData(
                encryptedData: encryptedData,
                vaultProviderConfigId: providerConfigId
            )
        )

        return try await payrailsAPI.saveInstrument(body: body)
    }

    // MARK: - Query

    /// Read-only access to SDK configuration and session state.
    /// Mirrors the web SDK's `payrails.query(key, params)` API.
    func query(_ key: PayrailsQueryKey) -> PayrailsQueryResult? {
        switch key {
        case .holderReference:
            guard let value = config?.holderReference else { return nil }
            return .string(value)

        case .amount:
            guard let amount = config?.amount else { return nil }
            return .amount(PayrailsAmount(value: amount.value, currency: amount.currency))

        case .executionId:
            guard let id = config?.execution?.id else { return nil }
            return .string(id)

        case .binLookup:
            guard let link = config?.execution?.links.lookup else { return nil }
            return .link(PayrailsLink(method: link.method, href: link.href))

        case .instrumentDelete:
            guard let link = config?.links?.instrumentDelete else { return nil }
            return .link(PayrailsLink(method: link.method, href: link.href))

        case .instrumentUpdate:
            guard let link = config?.links?.instrumentUpdate else { return nil }
            return .link(PayrailsLink(method: link.method, href: link.href))

        case .paymentMethodConfig(let filter):
            guard let config = config else { return nil }
            let all = config.allPaymentOptions()
            switch filter {
            case .all:
                return .paymentOptions(all.map(PayrailsPaymentOption.init))
            case .redirect:
                let redirectOptions = all.filter { $0.clientConfig?.flow == "redirect" }
                return .paymentOptions(redirectOptions.map(PayrailsPaymentOption.init))
            case .specific(let code):
                guard let option = all.first(where: { $0.paymentMethodCode == code }) else { return nil }
                return .paymentOptions([PayrailsPaymentOption(from: option)])
            }

        case .paymentMethodInstruments(let type):
            let instruments = storedInstruments(for: type)
            return .storedInstruments(instruments)
        }
    }
}
