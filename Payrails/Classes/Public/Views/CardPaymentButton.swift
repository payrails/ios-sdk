public protocol PayrailsCardPaymentButtonDelegate: AnyObject {
    func onPaymentButtonClicked(_ button: Payrails.CardPaymentButton)
    func onAuthorizeSuccess(_ button: Payrails.CardPaymentButton)
    func onThreeDSecureChallenge(_ button: Payrails.CardPaymentButton)
    func onAuthorizeFailed(_ button: Payrails.CardPaymentButton)
}

public extension Payrails {
    final class CardPaymentButton: ActionButton {
        private let cardForm: Payrails.CardForm
        private weak var session: Payrails.Session?
        private var paymentTask: Task<Void, Error>?
        private var encryptedCardData: String?
        private var isProcessing: Bool = false {
            didSet {
                self.isUserInteractionEnabled = !isProcessing
                show(loading: isProcessing)
            }
        }
        
        public weak var delegate: PayrailsCardPaymentButtonDelegate?
        public weak var presenter: PaymentPresenter?
        
        // Internal initializer used by factory method
        internal init(cardForm: Payrails.CardForm, session: Payrails.Session?, translations: CardPaymenButtonTranslations) {
            self.cardForm = cardForm
            self.session = session
            super.init()
            
            setupButton(translations: translations)
            cardForm.delegate = self
        }
        
        // Required initializers with warnings
        public required init() {
            fatalError("Use Payrails.createCardPaymentButton() instead")
        }
        
        public required init?(coder: NSCoder) {
            fatalError("Use Payrails.createCardPaymentButton() instead")
        }
        
        deinit {
            paymentTask?.cancel()
            if let session = session,
               session.isPaymentInProgress {
                session.cancelPayment()
            }
        }
        
        private func setupButton(translations: CardPaymenButtonTranslations) {
            setTitle(translations.label, for: .normal)
            backgroundColor = .systemBlue
            setTitleColor(.white, for: .normal)
            layer.cornerRadius = 8
            addTarget(self, action: #selector(payButtonTapped), for: .touchUpInside)
        }
        
        @objc private func payButtonTapped() {
            delegate?.onPaymentButtonClicked(self)
            cardForm.collectFields()
        }
        
        public func pay(with type: Payrails.PaymentType? = nil,
                       storedInstrument: StoredInstrument? = nil) {
            guard let presenter = self.presenter else {
                Payrails.log("Payment presenter not set")
                return
            }
            
            let paymentType = type ?? .card
            
            print("-----------------------")
            print("Save instrument:",  self.cardForm.saveInstrument)
            print("-----------------------")
            
            paymentTask = Task { [weak self, weak session] in
                self?.isProcessing = true
                
                var result: OnPayResult?
                if let session = session {
                    if var cardPaymentPresenter = presenter as? (any PaymentPresenter) {
                        // Use the saveInstrument value from the CardForm
                        let saveInstrument = self?.cardForm.saveInstrument ?? false
                        result = await session.executePayment(
                            with: paymentType,
                            saveInstrument: saveInstrument,
                            presenter: presenter
                        )
                    }
                } else if let storedInstrument = storedInstrument, let session = session {
                    result = await session.executePayment(
                        withStoredInstrument: storedInstrument
                    )
                } else {
                    Payrails.log("Missing required payment data or session")
                }
                
                await MainActor.run {
                    self?.handlePaymentResult(result)
                    self?.isProcessing = false
                }
            }
        }
        
        private func handlePaymentResult(_ result: OnPayResult?) {
            switch result {
            case .success:
                delegate?.onAuthorizeSuccess(self)
            case .authorizationFailed:
                delegate?.onAuthorizeFailed(self)
            case .failure:
                delegate?.onAuthorizeFailed(self)
            case .error(_):
                delegate?.onAuthorizeFailed(self)
            case .cancelledByUser:
                Payrails.log("Payment was cancelled by user")
            default:
                Payrails.log("Payment result: unknown state")
            }
        }
    }
}

// MARK: - PayrailsCardFormDelegate
extension Payrails.CardPaymentButton: PayrailsCardFormDelegate {
    public func cardForm(_ view: Payrails.CardForm, didCollectCardData data: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.encryptedCardData = data
            self.presenter?.encryptedCardData = encryptedCardData
            // Start the payment process
            self.pay(with: .card)
        }
    }
    
    public func cardForm(_ view: Payrails.CardForm, didFailWithError error: Error) {
        Payrails.log("Card collection failed: \(error.localizedDescription)")
        // Could notify delegate here if needed
    }
}
