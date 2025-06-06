import UIKit

@available(*, deprecated, message: "Use PayrailsCardPaymentButtonDelegate with CardPaymentButton in stored instrument mode instead")
public protocol PayrailsStoredInstrumentPaymentButtonDelegate: AnyObject {
    func onPaymentButtonClicked(_ button: Payrails.StoredInstrumentPaymentButton)
    func onAuthorizeSuccess(_ button: Payrails.StoredInstrumentPaymentButton)
    func onAuthorizeFailed(_ button: Payrails.StoredInstrumentPaymentButton)
}

public struct StoredInstrumentButtonTranslations {
    public let label: String
    public let processingLabel: String
    
    public init(label: String = "Pay", processingLabel: String = "Processing...") {
        self.label = label
        self.processingLabel = processingLabel
    }
}

public struct StoredInstrumentButtonStyle {
    public let backgroundColor: UIColor
    public let textColor: UIColor
    public let font: UIFont
    public let cornerRadius: CGFloat
    public let height: CGFloat
    public let borderWidth: CGFloat
    public let borderColor: UIColor
    public let contentEdgeInsets: UIEdgeInsets
    
    public init(
        backgroundColor: UIColor = .systemBlue,
        textColor: UIColor = .white,
        font: UIFont = .systemFont(ofSize: 16, weight: .medium),
        cornerRadius: CGFloat = 8,
        height: CGFloat = 44,
        borderWidth: CGFloat = 0,
        borderColor: UIColor = .clear,
        contentEdgeInsets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
    ) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.font = font
        self.cornerRadius = cornerRadius
        self.height = height
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.contentEdgeInsets = contentEdgeInsets
    }
    
    public static let defaultStyle = StoredInstrumentButtonStyle()
}

public extension Payrails {
    @available(*, deprecated, message: "Use CardPaymentButton with storedInstrument parameter instead. Example: Payrails.createCardPaymentButton(storedInstrument: instrument, ...)")
    final class StoredInstrumentPaymentButton: ActionButton {
        private let storedInstrument: StoredInstrument
        private weak var session: Payrails.Session?
        private var paymentTask: Task<Void, Error>?
        private let translations: StoredInstrumentButtonTranslations
        private var isProcessing: Bool = false {
            didSet {
                self.isUserInteractionEnabled = !isProcessing
                show(loading: isProcessing)
                updateButtonTitle()
            }
        }
        
        public weak var delegate: PayrailsStoredInstrumentPaymentButtonDelegate?
        public weak var presenter: PaymentPresenter?
        
        // Internal initializer used by factory method
        internal init(
            storedInstrument: StoredInstrument,
            session: Payrails.Session?,
            translations: StoredInstrumentButtonTranslations,
            style: StoredInstrumentButtonStyle
        ) {
            self.storedInstrument = storedInstrument
            self.session = session
            self.translations = translations
            super.init()
            
            setupButton(style: style)
        }
        
        // Required initializers with warnings
        public required init() {
            fatalError("Use Payrails.createStoredInstruments() instead")
        }
        
        public required init?(coder: NSCoder) {
            fatalError("Use Payrails.createStoredInstruments() instead")
        }
        
        deinit {
            paymentTask?.cancel()
            if let session = session,
               session.isPaymentInProgress {
                session.cancelPayment()
            }
        }
        
        private func setupButton(style: StoredInstrumentButtonStyle) {
            updateButtonTitle()
            backgroundColor = style.backgroundColor
            setTitleColor(style.textColor, for: .normal)
            titleLabel?.font = style.font
            layer.cornerRadius = style.cornerRadius
            layer.borderWidth = style.borderWidth
            layer.borderColor = style.borderColor.cgColor
            contentEdgeInsets = style.contentEdgeInsets
            
            // Set height constraint
            heightAnchor.constraint(equalToConstant: style.height).isActive = true
            
            addTarget(self, action: #selector(payButtonTapped), for: .touchUpInside)
        }
        
        private func updateButtonTitle() {
            let title = isProcessing ? translations.processingLabel : translations.label
            setTitle(title, for: .normal)
        }
        
        @objc private func payButtonTapped() {
            delegate?.onPaymentButtonClicked(self)
            pay()
        }
        
        public func pay() {
            guard let presenter = self.presenter else {
                Payrails.log("Payment presenter not set")
                return
            }
            
            guard let session = session else {
                Payrails.log("Session not available")
                return
            }
            print("🧩🧩🧩🧩🧩🧩🧩🧩🧩🧩")
            print("pay with stored instrument")
            
            paymentTask = Task { [weak self, weak session] in
                await MainActor.run {
                    self?.isProcessing = true
                }
                
                var result: OnPayResult?
                if let session = session {
                    result = await session.executePayment(
                        withStoredInstrument: self?.storedInstrument ?? self!.storedInstrument,
                        presenter: presenter
                    )
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
        
        public func getStoredInstrument() -> StoredInstrument {
            return storedInstrument
        }
    }
}
