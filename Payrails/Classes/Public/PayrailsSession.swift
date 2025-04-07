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
                let paymentHandler else {
                return
            }
            
            paymentHandler.makePayment(total: 99.0, currency: "USD", presenter: presenter)
        }

        public func cancelPayment() {
            isPaymentInProgress = false
            currentTask?.cancel()
            currentTask = nil
        }

        private func prepareHandler(
            for type: PaymentType,
            saveInstrument: Bool,
            presenter: PaymentPresenter?
        ) -> Bool {
            print("step-1 prepareHandler for" + String(describing: type))
            
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
    func paymentHandlerDidFinish(
        handler: PaymentHandler,
        type: Payrails.PaymentType, // <-- Use this parameter!
        status: PaymentHandlerStatus,
        payload: [String: Any]?
    ) {
        switch status {
        case .canceled:
            isPaymentInProgress = false
            onResult?(.cancelledByUser)
        case .success:
            if type == .card {
                if let payload = payload,
                   let paymentInstrumentData = payload["paymentInstrumentData"] as? [String: Any],
                   let cardData = paymentInstrumentData["card"] as? [String: Any],
                   let encryptedData = cardData["encryptedData"] as? String,
                   let vaultProviderConfigId = cardData["vaultProviderConfigId"] as? String,
                   let storeInstrument = payload["storeInstrument"] as? Bool {

                    // Construct the body specifically for Card
                    let country = Country(code: "DE", fullName: "Germany", iso3: "DEU") // TODO: Review hardcoded country
                    let billingAddress = BillingAddress(country: country)

                    let instrumentData = PaymentInstrumentData(
                        encryptedData: encryptedData,
                        vaultProviderConfigId: vaultProviderConfigId,
                        billingAddress: billingAddress
                    )

                    let amount = Amount(value: self.config.amount.value, currency: self.config.amount.currency)

                    let paymentComposition = PaymentComposition(
                        paymentMethodCode: type.rawValue, // .card
                        integrationType: "api",
                        amount: amount,
                        storeInstrument: storeInstrument,
                        paymentInstrumentData: instrumentData,
                        enrollInstrumentToNetworkOffers: false
                    )

                    // Prepare the final request body for Card
                    let returnInfo: [String: String] = [
                         "success": "https://assets.payrails.io/html/payrails-success.html",
                         "cancel": "https://assets.payrails.io/html/payrails-cancel.html",
                         "error": "https://assets.payrails.io/html/payrails-error.html",
                         "pending": "https://assets.payrails.io/html/payrails-pending.html"
                    ]
                    let risk = ["sessionId": "03bf5b74-d895-48d9-a871-dcd35e609db8"] // TODO: Make session ID dynamic
                    let meta = ["risk": risk]
                    let amountDict = ["value": amount.value, "currency": amount.currency]

                    let body: [String: Any] = [
                        "amount": amountDict,
                        "paymentComposition": [paymentComposition],
                        "returnInfo": returnInfo,
                        "meta": meta
                    ]

                    print("Final body for Card: \(body)")

                    // Make the API call for Card
                    currentTask = Task { [weak self] in
                        guard let strongSelf = self else { return }
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

                } else {
                    // Error: Payload structure is wrong even though type is .card
                    print("❌ Card payload structure mismatch.")
                    handle(error: PayrailsError.invalidDataFormat)
                }

            } else if type == .payPal {
                // Extract necessary data from the PayPal payload
                // *** VERIFY THIS PAYLOAD STRUCTURE AND REQUIRED FIELDS WITH PAYRAILS API DOCS FOR PAYPAL ***
                guard let payload = payload,
                      let storeInstrument = payload["storeInstrument"] as? Bool else {
                        // Optionally extract providerData if needed:
                        // let paymentInstrumentData = payload["paymentInstrumentData"] as? [String: Any]
                        // let providerData = paymentInstrumentData?["providerData"] as? [String: Any]
                        // let merchantId = providerData?["merchantId"] as? String
                    print("❌ PayPal payload missing required keys (e.g., storeInstrument). Payload: \(String(describing: payload))")
                    handle(error: PayrailsError.invalidDataFormat)
                    return
                }

                let amount = Amount(value: self.config.amount.value, currency: self.config.amount.currency)

                // Construct a PaymentComposition suitable for PayPal post-approval
                // This might not need 'paymentInstrumentData' or might need different fields (e.g., providerData).
                // Assuming paymentInstrumentData is not needed or should be constructed differently. VERIFY!
                let payPalComposition = PaymentComposition(
                    paymentMethodCode: type.rawValue, // .payPal
                    integrationType: "api", // Or maybe "sdk" / "redirect"? Check Payrails docs.
                    amount: amount,
                    storeInstrument: storeInstrument,
                    paymentInstrumentData: nil, // <-- Assuming nil, VERIFY!
                    enrollInstrumentToNetworkOffers: false
                )

                // Prepare the final request body for PayPal
                let returnInfo: [String: String] = [
                    "success": "https://assets.payrails.io/html/payrails-success.html",
                    "cancel": "https://assets.payrails.io/html/payrails-cancel.html",
                    "error": "https://assets.payrails.io/html/payrails-error.html",
                    "pending": "https://assets.payrails.io/html/payrails-pending.html"
                ]
                let risk = ["sessionId": "03bf5b74-d895-48d9-a871-dcd35e609db8"] // TODO: Make session ID dynamic
                let meta = ["risk": risk]
                let amountDict = ["value": amount.value, "currency": amount.currency]

                let payPalBody: [String: Any] = [
                    "amount": amountDict,
                    "paymentComposition": [payPalComposition],
                    "returnInfo": returnInfo,
                    "meta": meta
                ]

                // Make the API call for PayPal
                currentTask = Task { [weak self] in
                    guard let strongSelf = self else { return }
                    do {
                        let paymentStatus = try await strongSelf.payrailsAPI.makePayment(
                            type: type, // .payPal
                            payload: payPalBody // Use the PayPal-specific body
                        )
                        strongSelf.handle(paymentStatus: paymentStatus)
                    } catch {
                        strongSelf.handle(error: error)
                    }
                }

            } else if type == .applePay {
                 print("❌ Apple Pay success handling not fully implemented yet.")
                 handle(error: PayrailsError.incorrectPaymentSetup(type: type)) // Placeholder

            } else {
                print("❓ Unhandled payment type in success case: \(type)")
                handle(error: PayrailsError.unsupportedPayment(type: type))
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
        print("Payment Status:", paymentStatus)    
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


