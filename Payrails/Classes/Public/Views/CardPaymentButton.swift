public protocol PayrailsCardPaymentButtonDelegate: AnyObject {
    func onPaymentButtonClicked(_ button: Payrails.CardPaymentButton)
    func onAuthorizeSuccess(_ button: Payrails.CardPaymentButton)
    func onThreeDSecureChallenge(_ button: Payrails.CardPaymentButton)
    func onAuthorizeFailed(_ button: Payrails.CardPaymentButton)
}

public extension Payrails {
    final class CardPaymentButton: ActionButton {
        // Optional properties for dual mode support
        private let cardForm: Payrails.CardForm?
        private let storedInstrument: StoredInstrument?
        private weak var session: Payrails.Session?
        private var paymentTask: Task<Void, Error>?
        private var encryptedCardData: String?
        private var isProcessing: Bool = false {
            didSet {
                self.isUserInteractionEnabled = !isProcessing
                show(loading: isProcessing)
                updateButtonTitle()
            }
        }
        
        // Mode detection
        private var isStoredInstrumentMode: Bool {
            return storedInstrument != nil
        }
        
        // Translations for different modes
        private let translations: CardPaymenButtonTranslations
        private let storedInstrumentTranslations: StoredInstrumentButtonTranslations?
        
        public weak var delegate: PayrailsCardPaymentButtonDelegate?
        public weak var presenter: PaymentPresenter?
        
        // Card form mode initializer (existing)
        internal init(cardForm: Payrails.CardForm, session: Payrails.Session?, translations: CardPaymenButtonTranslations, buttonStyle: CardButtonStyle? = nil) {
            self.cardForm = cardForm
            self.storedInstrument = nil
            self.session = session
            self.translations = translations
            self.storedInstrumentTranslations = nil
            super.init()
            
            setupButton(style: buttonStyle)
            cardForm.delegate = self
        }
        
        // Stored instrument mode initializer (new)
        internal init(storedInstrument: StoredInstrument, session: Payrails.Session?, translations: CardPaymenButtonTranslations, storedInstrumentTranslations: StoredInstrumentButtonTranslations? = nil, buttonStyle: StoredInstrumentButtonStyle? = nil) {
            self.cardForm = nil
            self.storedInstrument = storedInstrument
            self.session = session
            self.translations = translations
            self.storedInstrumentTranslations = storedInstrumentTranslations
            super.init()
            
            setupButton(storedInstrumentStyle: buttonStyle)
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
        
        private func setupButton(style: CardButtonStyle? = nil) {
            updateButtonTitle()
            
            // Use provided style or fall back to default
            let buttonStyle = style ?? CardButtonStyle.defaultStyle
            
            // Apply style properties
            if let bgColor = buttonStyle.backgroundColor {
                backgroundColor = bgColor
            }
            if let textColor = buttonStyle.textColor {
                setTitleColor(textColor, for: .normal)
            }
            if let font = buttonStyle.font {
                titleLabel?.font = font
            }
            if let cornerRadius = buttonStyle.cornerRadius {
                layer.cornerRadius = cornerRadius
            }
            if let borderWidth = buttonStyle.borderWidth {
                layer.borderWidth = borderWidth
            }
            if let borderColor = buttonStyle.borderColor {
                layer.borderColor = borderColor.cgColor
            }
            if let contentEdgeInsets = buttonStyle.contentEdgeInsets {
                self.contentEdgeInsets = contentEdgeInsets
            }
            
            addTarget(self, action: #selector(payButtonTapped), for: .touchUpInside)
        }
        
        private func setupButton(storedInstrumentStyle: StoredInstrumentButtonStyle? = nil) {
            updateButtonTitle()
            
            if let style = storedInstrumentStyle {
                backgroundColor = style.backgroundColor
                setTitleColor(style.textColor, for: .normal)
                titleLabel?.font = style.font
                layer.cornerRadius = style.cornerRadius
                layer.borderWidth = style.borderWidth
                layer.borderColor = style.borderColor.cgColor
                contentEdgeInsets = style.contentEdgeInsets
                
                // Set height constraint
                heightAnchor.constraint(equalToConstant: style.height).isActive = true
            } else {
                // Default styling
                backgroundColor = .systemBlue
                setTitleColor(.white, for: .normal)
                layer.cornerRadius = 8
            }
            
            addTarget(self, action: #selector(payButtonTapped), for: .touchUpInside)
        }
        
        private func updateButtonTitle() {
            if isStoredInstrumentMode {
                // Use stored instrument translations if available
                if let storedTranslations = storedInstrumentTranslations {
                    let title = isProcessing ? storedTranslations.processingLabel : storedTranslations.label
                    setTitle(title, for: .normal)
                } else {
                    // Fallback to card translations
                    setTitle(translations.label, for: .normal)
                }
            } else {
                // Card form mode - use card translations
                setTitle(translations.label, for: .normal)
            }
        }
        
        @objc private func payButtonTapped() {
            delegate?.onPaymentButtonClicked(self)
            
            if let cardForm = cardForm {
                // Card form mode: collect card data first
                cardForm.collectFields()
            } else if let storedInstrument = storedInstrument {
                // Stored instrument mode: direct payment
                pay(with: storedInstrument.type, storedInstrument: storedInstrument)
            }
        }
        
        public func pay(with type: Payrails.PaymentType? = nil,
                       storedInstrument: StoredInstrument? = nil) {
            guard let presenter = self.presenter else {
                Payrails.log("Payment presenter not set")
                return
            }
            
            guard let session = session else {
                Payrails.log("Session not available")
                return
            }
            
            let paymentType = type ?? .card
            
            if isStoredInstrumentMode {
                print("🧩🧩🧩🧩🧩🧩🧩🧩🧩🧩")
                print("pay with stored instrument")
            } else {
                print("-----------------------")
                print("Save instrument:",  self.cardForm?.saveInstrument ?? false)
                print("-----------------------")
            }
            
            paymentTask = Task { [weak self, weak session] in
                await MainActor.run {
                    self?.isProcessing = true
                }
                
                var result: OnPayResult?
                if let session = session {
                    if let storedInstrument = storedInstrument ?? self?.storedInstrument {
                        // Stored instrument payment
                        result = await session.executePayment(
                            withStoredInstrument: storedInstrument,
                            presenter: presenter
                        )
                    } else {
                        // Card form payment
                        let saveInstrument = self?.cardForm?.saveInstrument ?? false
                        result = await session.executePayment(
                            with: paymentType,
                            saveInstrument: saveInstrument,
                            presenter: presenter
                        )
                    }
                } else {
                    Payrails.log("Session is no longer available")
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
        
        // Public method to get the stored instrument (for stored instrument mode)
        public func getStoredInstrument() -> StoredInstrument? {
            return storedInstrument
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
