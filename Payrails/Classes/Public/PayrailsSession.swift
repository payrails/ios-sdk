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
        // 2- [rev. question] : what does these two properties do ? applePayTokenizeContinuation and applePayTokenizeOptions
        /// Bridges the Apple Pay sheet's delegate callbacks back into the `async tokenize`
        /// call: held while the sheet is open, resumed exactly once when tokenization
        /// finishes, fails, or the user cancels.
        private var applePayTokenizeContinuation: CheckedContinuation<SaveInstrumentResponse, Error>?
        private var applePayTokenizeOptions = TokenizeOptions()
        private var paymentHandler: PaymentHandler?
        private var currentTask: Task<Void, Error>?
        private var payrailsCSE: PayrailsCSE?

        /// Runs in parallel with the 3DS WebView; whichever signal (WebView terminal URL or
        /// backend terminal status) arrives first wins, guarded by `terminalReported`.
        private var backgroundPollTask: Task<Void, Never>?

        /// Single-shot guard ensuring the payment outcome is reported exactly once,
        /// regardless of whether it arrives via the WebView delegate or background polling.
        private var terminalReported = false
        private let terminalLock = NSLock()

        /// Captured at the start of the pending phase so the user-dismissed-3DS
        /// confirmation poll knows which execution to query.
        private var challengeExecutionUrl: URL?

        /// Optional refresh handler supplied by the merchant at `createSession` time.
        /// Invoked by `refreshIfPossible()` after the SDK detects the Payrails execution
        /// is poisoned (e.g. user abandoned 3DS, no terminal confirmed) so the SDK can
        /// rebuild its internal config in place without forcing the merchant to recreate
        /// the `Session` and reassign it on every cached button / form.
        private let onSessionExpired: SessionExpiredHandler?

        /// Single-shot guard preventing overlapping refreshes. Cleared once the closure's
        /// completion fires (whether success or failure).
        private var isRefreshing = false
        private let refreshLock = NSLock()

        var debugConfig: SDKConfig {
            return self.config
        }

        private(set) var isPaymentInProgress = false {
            didSet {
                payrailsAPI.isRunning = isPaymentInProgress
            }
        }

        init(
            _ configuration: Payrails.Configuration,
            onSessionExpired: SessionExpiredHandler? = nil
        ) throws {
            self.option = configuration.option
            self.onSessionExpired = onSessionExpired
            self.config = try parse(config: configuration)

            self.payrailsAPI = PayrailsAPI(config: config)

            executionId = config.execution?.id

            do {
                self.payrailsCSE = try PayrailsCSE(data: configuration.initData.data, version: configuration.initData.version)
            } catch {
                print("Failed to initialize PayrailsCSE:", error)
            }

            if onSessionExpired == nil {
                Payrails.log("⚠️ No onSessionExpired handler provided to createSession. The SDK cannot self-heal if the user abandons a 3DS challenge — the next payment attempt against this Session will fail. See SessionExpiredHandler docs.")
            }
        }

        /// Returns `true` if the device supports Apple Pay at the platform level.
        ///
        /// This is a pure device-capability check (backed by
        /// `PKPaymentAuthorizationController.canMakePayments()`). It does NOT check
        /// whether Apple Pay is configured for this session — that's a separate
        /// concern answered by `getPaymentMethodConfig(_:)`.
        ///
        /// Mirrors the web SDK's `isApplePayAvailable()`.
        ///
        /// For the combined "configured and device capable" signal, compose:
        /// ```
        /// let canShow = session.isApplePayAvailable
        ///     && !session.getPaymentMethodConfig(.specific("apple_pay")).isEmpty
        /// ```
        public var isApplePayAvailable: Bool {
            PKPaymentAuthorizationController.canMakePayments()
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
            resetTerminalGuard()

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
            resetTerminalGuard()

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
                onResult(.authorizationFailed(.unknownError(.invalidDataFormat)))
                isPaymentInProgress = false
                return
            }

            paymentHandler.makePayment(total: total, currency: config.amount.currency, presenter: presenter)
        }

        /// Presents the Apple Pay sheet in TOKENIZE mode. The outcome flows back through the
        /// PaymentHandlerDelegate callbacks, which resume `applePayTokenizeContinuation`.
        private func presentApplePayTokenizationSheet(presenter: PaymentPresenter?) {
            // 3- [rev. question] : what the config is ?
            // 4- [rev. question] : is the paymentComposition here is coming from the /init response ?
            guard let paymentComposition = config.paymentOption(for: .applePay),
                  case let .applePay(applePayConfig) = paymentComposition.config else {
                finishApplePayTokenization(with: .failure(PayrailsError.unsupportedPayment(type: .applePay)))
                return
            }
            guard let total = Double(config.amount.value) else {
                finishApplePayTokenization(with: .failure(PayrailsError.invalidDataFormat))
                return
            }

            // 5- [rev. question] : Do we call the payment handler here to present the apple pay sheet ?
            let handler = ApplePayHandler(
                config: applePayConfig,
                delegate: self,
                saveInstrument: true,
                // 6- [rev. question] : what does this `mode` do ? this is to instruct the sheet to show the sheet to obtina apple pay token ?
                // 7- [rev. question] : where this property `mode` is declared ?
                mode: .tokenize
            )
            self.paymentHandler = handler
            handler.makePayment(total: total, currency: config.amount.currency, presenter: presenter)
        }

        /// Resumes the pending tokenization continuation exactly once, then clears state.
        private func finishApplePayTokenization(with result: Result<SaveInstrumentResponse, Error>) {
            applePayTokenizeContinuation?.resume(with: result)
            applePayTokenizeContinuation = nil
            paymentHandler = nil
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
                onResult?(.authorizationFailed(.unknownError(.unsupportedPayment(type: type))))
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
                    onResult?(.authorizationFailed(.unknownError(.incorrectPaymentSetup(type: type))))
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
                    onResult?(.authorizationFailed(.unknownError(.incorrectPaymentSetup(type: type))))
                    return false
                }
            case .card:
                guard let providerConfigId = config.vaultConfiguration?.providerConfigId,
                      !providerConfigId.isEmpty else {
                    isPaymentInProgress = false
                    onResult?(.authorizationFailed(.unknownError(.missingData("Vault configuration with providerConfigId is required for card payments."))))
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
            // Backend-confirmed cancel: the issuer redirected to the cancel URL, so the
            // execution reached a clean terminal. No session refresh needed — only the
            // abandonment path (no backend terminal) leaves the execution reusable-but-pending.
            // this will never happen based on backend polling.
            guard claimTerminal() else { return }
            cancelBackgroundPolling()
            isPaymentInProgress = false
            onResult?(.authorizationFailed(.userCancelled))
            onResult = nil
            paymentHandler = nil

        case .success:
            // Not yet terminal — the confirmation phase still has to run. But the background
            // poll started during the pending phase would now race against the confirmation
            // poll, so cancel it here.
            cancelBackgroundPolling()
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
            // Clean terminal reached via the WebView error URL — the execution is closed,
            // not left pending, so no refresh.
            guard claimTerminal() else { return }
            cancelBackgroundPolling()
            isPaymentInProgress = false
            let finalError = error ?? PayrailsError.unknown(error: nil)
            onResult?(.authorizationFailed(.unknownError(finalError as? PayrailsError)))
            onResult = nil
            paymentHandler = nil
        }
    }

    func paymentHandlerDidFail(
        handler: PaymentHandler,
        error: PayrailsError,
        type: Payrails.PaymentType
    ) {
        guard claimTerminal() else { return }
        cancelBackgroundPolling()
        isPaymentInProgress = false
        onResult?(.authorizationFailed(.unknownError(error)))
        paymentHandler = nil
    }

    /// Handler captured an Apple Pay token in tokenize mode. Save it via the shared core,
    /// then close the sheet (`completion`). The awaiting `tokenize` call resumes only after
    /// Apple Pay reports that its controller has fully dismissed.
    func paymentHandlerDidRequestTokenization(
        handler: PaymentHandler,
        paymentToken: String,
        completion: @escaping (Result<SaveInstrumentResponse, PayrailsError>) -> Void
    ) {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let response = try await self.saveInstrument(
                    paymentMethod: "applePay",
                    data: SaveInstrumentBodyData(paymentToken: paymentToken),
                    options: self.applePayTokenizeOptions
                )
                await MainActor.run {
                    completion(.success(response))
                }
            } catch {
                let payrailsError = (error as? PayrailsError) ?? .unknown(error: error)
                await MainActor.run {
                    completion(.failure(payrailsError))
                }
            }
        }
    }

    func paymentHandlerDidFinishTokenization(
        handler: PaymentHandler,
        result: Result<SaveInstrumentResponse, Error>
    ) {
        finishApplePayTokenization(with: result)
    }

    /// Tokenization ended without a usable token (user dismissed the sheet, or serialization
    /// failed). Resume the awaiting `tokenize` call by throwing.
    func paymentHandlerDidFailTokenization(handler: PaymentHandler, error: Error) {
        finishApplePayTokenization(with: .failure(error))
    }

    /// Called when the user interactively dismissed the 3DS challenge (e.g. swipe-down on
    /// the modal). Two things to figure out before reporting an outcome:
    ///
    ///   1. Did the backend actually reach a terminal status that we just haven't
    ///      observed yet? If yes, report that terminal — NOT a cancellation.
    ///   2. If we genuinely can't confirm a terminal within a brief window, the user
    ///      abandoned the flow and the execution is left in pending state on the backend.
    ///      Emit `.authorizationFailed(.userCancelled)` and kick off the Session's in-place
    ///      refresh via the merchant's `onSessionExpired` closure (the execution is
    ///      reusable-but-pending, so the next attempt would otherwise be blocked).
    ///
    /// Uses a 6-attempt × 1s confirmation poll (per @kumaraksi's review on PR #78: a fixed
    /// wait can give false negatives if backend reconciliation takes longer). Matches the
    /// Web SDK's redirect-cancel pattern in `web-sdk/.../generic-redirect/index.ts:491-518`.
    func paymentHandlerUserDidDismissChallenge(handler: PaymentHandler) {
        let confirmationPollAttempts = 3
        let confirmationPollInterval: UInt64 = 1_000_000_000   // 1 second

        Task { [weak self] in
            guard let self = self, let url = self.challengeExecutionUrl else {
                // No execution URL captured — we can only fall through to declaring
                // cancellation. Should not happen in practice (the URL is captured at
                // startBackgroundPollingDuringChallenge time).
                await MainActor.run { [weak self] in self?.emitUserCancelledAfterDismiss() }
                return
            }

            for attempt in 1...confirmationPollAttempts {
                if Task.isCancelled { return }
                // Use the bounded one-shot read here — NOT pollForTerminalDuringChallenge,
                // which can block for up to ~310s on its internal long poll and would leave
                // the button spinning until it returns. The grace window must resolve in a
                // few seconds so .userCancelled can be surfaced and the loading state cleared.
                if let status = try? await self.payrailsAPI.fetchTerminalStatusOnce(executionUrl: url) {
                    // The backend has reached a real terminal during the grace window.
                    // Route it through the normal handler so the merchant sees the
                    // ACTUAL outcome (success/failure with backend data), NOT a cancellation.
                    await MainActor.run { [weak self] in
                        self?.handleBackgroundPollTerminal(status: status)
                    }
                    return
                }
                if attempt < confirmationPollAttempts {
                    try? await Task.sleep(nanoseconds: confirmationPollInterval)
                }
            }

            // All attempts exhausted with no backend terminal — the user abandoned the flow
            // and the execution remains pending. Surface .userCancelled and refresh.
            await MainActor.run { [weak self] in self?.emitUserCancelledAfterDismiss() }
        }
    }

    /// Single-shot terminal claim for the user-dismissed-with-no-resolution path.
    /// Bails silently if the background poll already reported a real terminal.
    ///
    /// Surfaces `.authorizationFailed(.userCancelled)` to the caller, then fires
    /// `refreshIfPossible()` because the execution is left non-terminal (pending) on the
    /// backend — the merchant's next payment attempt would otherwise hit the dead execution.
    private func emitUserCancelledAfterDismiss() {
        guard claimTerminal() else { return }
        cancelBackgroundPolling()
        isPaymentInProgress = false
        onResult?(.authorizationFailed(.userCancelled))
        onResult = nil
        paymentHandler = nil
        // Non-terminal-left: refresh so the next attempt works against a fresh execution.
        refreshIfPossible()
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
            onResult?(.authorizationFailed(.unknownError(.missingData("Link response is missing"))))
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
        case let .failed(message):
            guard claimTerminal() else { return }
            cancelBackgroundPolling()
            onResult?(.authorizationFailed(.authorizationError(message: message)))
        case .success:
            guard claimTerminal() else { return }
            cancelBackgroundPolling()
            onResult?(.success)
        case let .pending(executionResult):
            // Bail if a terminal has already been reported. Protects against late
            // `.pending` arrivals (e.g. an in-flight `confirmPayment` task completing
            // after the WebView / background poll already resolved the payment) firing
            // stale `paymentHandlerWillRequestChallengePresentation` callbacks on the
            // delegate — which would surface as a phantom `onThreeDSecureChallenge`
            // after `onAuthorizeFailed` / `onAuthorizeSuccess`.
            if isTerminalReported() { return }

            // Branch on `actionRequired`:
            //   - nil  → no action for the SDK to perform; surface `.pending` to the
            //            caller so the merchant can poll / refresh / decide.
            //   - else → perform the action (3DS challenge) and start the background
            //            poll so we can resolve the payment even if the WebView stalls.
            guard executionResult.actionRequired != nil else {
                guard claimTerminal() else { return }
                cancelBackgroundPolling()
                // Backend pending with no action for the SDK. The execution is still live
                // and may settle later, so surface `.pending` and do NOT refresh — refresh
                // is reserved for non-terminal-left abandonment / timeout paths.
                onResult?(.pending)
                break
            }
            paymentHandler?.handlePendingState(with: executionResult)
            startBackgroundPollingDuringChallenge(executionResult: executionResult)
            return
        }

        // `.failed` and `.success` are clean terminals — the execution is closed, not left
        // pending, so no refresh here.
        currentTask?.cancel()
        currentTask = nil
        isPaymentInProgress = false
        onResult = nil
        paymentHandler = nil
    }

    /// Single-shot guard: returns `true` only on the first call after each reset. Any subsequent
    /// caller (e.g. WebView delegate firing after background polling already resolved the
    /// payment) bails out without reporting a duplicate outcome.
    private func claimTerminal() -> Bool {
        terminalLock.lock()
        defer { terminalLock.unlock() }
        if terminalReported { return false }
        terminalReported = true
        return true
    }

    /// Lock-respecting read of the terminal-reported flag. Used by code paths that need
    /// to bail when a terminal has already fired but do NOT want to claim it themselves
    /// (e.g. a late `.pending` status that should not retrigger challenge presentation).
    private func isTerminalReported() -> Bool {
        terminalLock.lock()
        defer { terminalLock.unlock() }
        return terminalReported
    }

    private func resetTerminalGuard() {
        terminalLock.lock()
        terminalReported = false
        terminalLock.unlock()
    }

    /// Self-heals the Session in place when the merchant supplied a refresh handler.
    ///
    /// Called only from paths that leave the Payrails execution non-terminal (pending),
    /// where the next payment attempt against the cached `Session` would fail:
    ///   - `emitUserCancelledAfterDismiss()` — user abandoned 3DS, confirmation poll found
    ///     no terminal.
    ///   - `handle(error:)` for a polling timeout or an expired token (HTTP 401 / 403).
    /// Clean terminals (success, backend decline, cancel-URL) do NOT call this — the
    /// execution is already closed there.
    ///
    /// Behaviour:
    ///   - If no `onSessionExpired` handler was provided, this is a no-op (the
    ///     warning was already logged at `Session.init` time).
    ///   - If a refresh is already in flight, the second call is a no-op (guarded
    ///     by `isRefreshing`).
    ///   - On success: re-parse the fresh `InitData`, rebuild `config`,
    ///     `payrailsAPI`, `payrailsCSE`, and `executionId` in place. The
    ///     merchant's `Session` reference and every cached button/form keep
    ///     working — only the underlying execution changes.
    ///   - On failure: log and leave the Session as-is. The next payment tap will
    ///     fail naturally with whatever the dead execution emits.
    private func refreshIfPossible() {
        guard let handler = onSessionExpired else { return }

        refreshLock.lock()
        if isRefreshing {
            refreshLock.unlock()
            return
        }
        isRefreshing = true
        refreshLock.unlock()

        handler { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                defer {
                    self.refreshLock.lock()
                    self.isRefreshing = false
                    self.refreshLock.unlock()
                }

                switch result {
                case let .success(newInitData):
                    do {
                        let newConfiguration = Payrails.Configuration(
                            initData: newInitData,
                            option: self.option
                        )
                        let newConfig = try self.parse(config: newConfiguration)
                        self.config = newConfig
                        self.payrailsAPI = PayrailsAPI(config: newConfig)
                        self.executionId = newConfig.execution?.id
                        do {
                            self.payrailsCSE = try PayrailsCSE(
                                data: newInitData.data,
                                version: newInitData.version
                            )
                        } catch {
                            Payrails.log("Session refresh: PayrailsCSE rebuild failed: \(error)")
                        }
                        Payrails.log("Session refreshed in place; new executionId=\(self.executionId ?? "<none>")")
                    } catch {
                        Payrails.log("Session refresh: parse failed: \(error)")
                    }
                case let .failure(error):
                    Payrails.log("Session refresh handler reported failure: \(error)")
                }
            }
        }
    }

    private func cancelBackgroundPolling() {
        backgroundPollTask?.cancel()
        backgroundPollTask = nil
    }

    /// Starts polling the workflow execution URL in parallel with the 3DS WebView. If the
    /// backend reaches `authorizeSuccessful` / `authorizeFailed` before the WebView lands on a
    /// recognized terminal URL (e.g. backend redirect chain stalls, network blip, unknown
    /// return URL), polling will resolve the payment and dismiss the WebView. Otherwise the
    /// WebView path wins and cancels this task.
    private func startBackgroundPollingDuringChallenge(executionResult: GetExecutionResult) {
        guard let url = URL(string: executionResult.links.`self`) else { return }
        // Capture the URL for the user-dismissed-3DS confirmation poll path.
        challengeExecutionUrl = url
        cancelBackgroundPolling()
        backgroundPollTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let status = try await self.payrailsAPI.pollForTerminalDuringChallenge(executionUrl: url)
                if Task.isCancelled { return }
                await MainActor.run { [weak self] in
                    self?.handleBackgroundPollTerminal(status: status)
                }
            } catch {
                // Background poll could not resolve the payment (timed out, network error, etc.).
                // Stay silent so the WebView path remains the primary resolution channel.
                #if DEBUG
                Payrails.log("Background polling ended without terminal: \(error)")
                #endif
            }
        }
    }

    private func handleBackgroundPollTerminal(status: PayrailsAPI.PaymentStatus) {
        // Only proceed if no terminal has been reported yet. If the WebView already resolved
        // the payment, this call is a no-op.
        guard claimTerminal() else { return }
        paymentHandler?.dismissPresentedView()
        // Route through the same handler that processes WebView-driven terminals so cleanup
        // and `onResult` propagation are identical.
        switch status {
        case let .failed(message):
            onResult?(.authorizationFailed(.authorizationError(message: message)))
        case .success:
            onResult?(.success)
        case .pending:
            // The polling target excludes `authorizePending`, so this branch should not occur.
            // If it does, treat as no-op and let the WebView path drive.
            return
        }
        // Background poll reached a clean terminal (`.success` / `.failed`) — the execution
        // is closed, not left pending, so no refresh.
        currentTask?.cancel()
        currentTask = nil
        isPaymentInProgress = false
        onResult = nil
        paymentHandler = nil
    }

    private func handle(error: Error) {
        Payrails.log("Call handle payment with error")
        guard claimTerminal() else { return }
        cancelBackgroundPolling()

        // `shouldRefresh` is true only when the execution is left non-terminal — i.e. the
        // SDK gave up without the backend committing a terminal status. That covers an
        // expired session token (401/403) and a polling timeout: in both cases the next
        // attempt would target a dead/pending execution unless we refresh. Decode failures,
        // missing data, and other hard errors are NOT refreshed.
        let failure: AuthorizationFailure
        var shouldRefresh = false

        if let payrailsError = error as? PayrailsError {
            switch payrailsError {
            case .authenticationError:
                // HTTP 401 / 403 — session token expired or invalid. Refreshing the session
                // is precisely the remedy, so this joins the non-terminal-left refresh set.
                failure = .authenticationError
                shouldRefresh = true
            case .pollingFailed, .finalStatusNotFoundAfterLongPoll, .longPollingFailed:
                // The poll exhausted without a terminal — the backend never committed an
                // outcome, leaving the execution pending. Honest code is `.unknownError`
                // (the SDK genuinely doesn't know the result); refresh so a retry works.
                failure = AuthorizationFailure(
                    code: .unknownError,
                    message: "The payment status could not be confirmed in time. Please try again.",
                    rawError: payrailsError
                )
                shouldRefresh = true
            default:
                failure = .unknownError(payrailsError)
            }
        } else {
            failure = .unknownError(PayrailsError.unknown(error: error))
        }

        onResult?(.authorizationFailed(failure))
        isPaymentInProgress = false
        onResult = nil
        paymentHandler = nil
        if shouldRefresh {
            refreshIfPossible()
        }
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

public extension Payrails.Session {
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

    public func deleteInstrument(instrumentId: String) async throws -> DeleteInstrumentResponse {
        return try await payrailsAPI.deleteInstrument(instrumentId: instrumentId)
    }

    public func updateInstrument(instrumentId: String, body: UpdateInstrumentBody) async throws -> UpdateInstrumentResponse {
        return try await payrailsAPI.updateInstrument(instrumentId: instrumentId, body: body)
    }

    /// Tokenizes a payment method by presenting the SDK's own UI (e.g. the Apple Pay sheet),
    /// capturing the token, and saving the instrument. Returns the saved instrument (use `.id`
    /// for the stable Payrails instrument id).
    ///
    /// Only methods the SDK tokenizes via presented UI are supported (currently `.applePay`).
    /// Cards tokenize via `cardForm.tokenize()`; other methods throw `.unsupportedPayment`.
    public func tokenize(
        _ method: Payrails.PaymentType,
        presenter: PaymentPresenter,
        options: TokenizeOptions = TokenizeOptions()
    ) async throws -> SaveInstrumentResponse {
        switch method {
        case .applePay:
            // Bridge the Apple Pay sheet's delegate callbacks into async/await. The continuation
            // is resumed (once) from the PaymentHandlerDelegate methods — AFTER the
            // create-instrument POST completes — so the sheet stays open across it.
            self.applePayTokenizeOptions = options
            return try await withCheckedThrowingContinuation { continuation in
                self.applePayTokenizeContinuation = continuation
                Task { @MainActor in
                    self.presentApplePayTokenizationSheet(presenter: presenter)
                }
            }
        case .card, .payPal, .genericRedirect:
            // Not tokenizable via a presented sheet here. Cards use `cardForm.tokenize()`.
            throw PayrailsError.unsupportedPayment(type: method)
        }
    }

    /// Card tokenization entry point (called by `CardForm.tokenize()`). Independent of the
    /// wallet `tokenize(_:presenter:)` path — cards have their own embedded-form collection, so
    /// this stays the single source of truth for card tokenization.
    func tokenize(encryptedData: String, options: TokenizeOptions) async throws -> SaveInstrumentResponse {
        guard let providerConfigId = config?.vaultConfiguration?.providerConfigId else {
            throw PayrailsError.missingData("Vault configuration with providerConfigId is required for card tokenization.")
        }
        return try await saveInstrument(
            paymentMethod: "card",
            data: SaveInstrumentBodyData(encryptedData: encryptedData, vaultProviderConfigId: providerConfigId),
            options: options
        )
    }

    /// Shared tokenization core: builds the request body and POSTs to the instruments
    /// endpoint (`POST /public/payment/instruments`). Used by BOTH the card and wallet paths,
    /// so the POST logic exists exactly once. The backend routes by `paymentMethod`.
    private func saveInstrument(
        paymentMethod: String,
        data: SaveInstrumentBodyData,
        options: TokenizeOptions
    ) async throws -> SaveInstrumentResponse {
        guard let holderReference = config?.holderReference else {
            throw PayrailsError.missingData("holderReference is required for tokenization.")
        }
        let body = SaveInstrumentBody(
            holderReference: holderReference,
            paymentMethod: paymentMethod,
            storeInstrument: options.storeInstrument,
            futureUsage: options.futureUsage.rawValue,
            data: data
        )
        return try await payrailsAPI.saveInstrument(body: body)
    }

    // MARK: - Payment method configuration

    /// Returns configuration for payment methods matching the given filter.
    ///
    /// Mirrors the web SDK's `getPaymentMethodConfig(paymentMethod)` API
    /// (`web-sdk/packages/web-sdk/src/sdk/headless/query/payment-methods.ts`).
    ///
    /// - Parameter filter:
    ///   - `.all` (default) returns every configured payment method.
    ///   - `.redirect` returns only methods with a redirect client flow.
    ///   - `.specific(code)` returns the method matching the given
    ///     `paymentMethodCode` — a single-element array, or empty if the code
    ///     is not configured.
    /// - Returns: an array of `PayrailsPaymentOption`. Empty when nothing matches.
    public func getPaymentMethodConfig(_ filter: PaymentMethodFilter = .all) -> [PayrailsPaymentOption] {
        guard let config = config else { return [] }
        let all = config.allPaymentOptions()
        switch filter {
        case .all:
            return all.map(PayrailsPaymentOption.init)
        case .redirect:
            return all
                .filter { $0.clientConfig?.flow == "redirect" }
                .map(PayrailsPaymentOption.init)
        case .specific(let code):
            guard let match = all.first(where: { $0.paymentMethodCode == code }) else { return [] }
            return [PayrailsPaymentOption(from: match)]
        }
    }

    // MARK: - Query

    /// Read-only access to SDK configuration and session state.
    /// Mirrors the web SDK's `payrails.query(key, params)` API.
    public func query(_ key: PayrailsQueryKey) -> PayrailsQueryResult? {
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
