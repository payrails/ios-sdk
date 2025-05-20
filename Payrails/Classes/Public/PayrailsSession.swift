import Foundation
import PassKit
import PayrailsCSE

public extension Payrails {
    class Session {
        private var config: SDKConfig!
        private var payrailsAPI: PayrailsAPI!
        private let option: Payrails.Options
        public var executionId: String?

        private var onResult: OnPayCallback?
        private var paymentHandler: PaymentHandler?
        private var currentTask: Task<Void, Error>?
        private var payrailsCSE: PayrailsCSE?
        
        var debugConfig: SDKConfig {
            return self.config
        }
     
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
            print(self.config);
            print("------------------------")
            print(self.config.paymentOption(for: PaymentType.genericRedirect))
            print("--------------------------")
            print(self.config.paymentOption(forPaymentMethodCode: "eftPro"))
            print("isapplepayabaial")
            print(isApplePayAvailable)
            print("isapplepayabaial")
            self.payrailsAPI = PayrailsAPI(config: config)
            if isPaymentAvailable(type: .card),
                  let vaultId = config.vaultConfiguration?.vaultId,
                  let vaultUrl = config.vaultConfiguration?.vaultUrl,
                  let token = config.vaultConfiguration?.token,
               let tableName = config.vaultConfiguration?.cardTableName {
            }

            executionId = config.execution?.id
            
            do {
                self.payrailsCSE = try PayrailsCSE(data: configuration.initData.data, version: configuration.initData.version)
            } catch {
                print("Failed to initialize PayrailsCSE:", error)
            }
        }
        

        
        public func isPaymentAvailable(type: PaymentType) -> Bool {
            return config.paymentOption(for: type) != nil
        }

        public var isApplePayAvailable: Bool {
            return config.paymentOption(for: .applePay) != nil
        }
        
        public func isPaymentCodeAvailable(paymentMethodCode: String) -> Bool {
            return config.paymentOption(forPaymentMethodCode: paymentMethodCode) != nil
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
            
            paymentHandler.makePayment(total: Double(config.amount.value)!, currency: config.amount.currency, presenter: presenter)
        }

        public func cancelPayment() {
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
                print("0-000-9-09-09-09-09-")
                print("here is paymentMethodCope", paymentMethodCode)
                print("0-000-9-09-09-09-09-")
                paymentComposition = config.paymentOption(forPaymentMethodCode: code)
            } else {
                paymentComposition = config.paymentOption(for: type)
                print("0-11111111111111-9-09-09-09-09-")
                print("here is paymentMethodCope", paymentMethodCode)
                print("0-111111111111111-09-")
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
        } else {
            print("Session Warning: CardPaymentHandler's presenter does not conform to PayrailsCardPaymentFormDelegate.")
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
                    print("payment is coming")
                    print(body)
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
        Payrails.log("Call handle payment withn status", paymentStatus)
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

public extension Payrails.Session {
    func getCSEInstance() -> PayrailsCSE? {
        return payrailsCSE
    }
}

public extension Payrails.Session {
    func getSDKConfiguration() -> PublicSDKConfig? {
        guard let config = self.config else { return nil }
        return PublicSDKConfig(from: config)
    }
}


