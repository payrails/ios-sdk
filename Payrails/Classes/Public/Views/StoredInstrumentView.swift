import UIKit

public protocol PayrailsStoredInstrumentViewDelegate: AnyObject {
    func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didSelectInstrument instrument: StoredInstrument)
    func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didDeselectInstrument instrument: StoredInstrument)
    func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didCompletePaymentForInstrument instrument: StoredInstrument)
    func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didFailPaymentForInstrument instrument: StoredInstrument, error: PayrailsError)
}

public extension Payrails {
    final class StoredInstrumentView: UIView {
        private let instrument: StoredInstrument
        private weak var session: Payrails.Session?
        private let style: StoredInstrumentsStyle
        private let translations: StoredInstrumentsTranslations
        private let containerView: UIView
        private let labelView: UILabel
        private let paymentButton: Payrails.StoredInstrumentPaymentButton
        private let tapGestureRecognizer: UITapGestureRecognizer
        private var isSelected: Bool = false
        
        public weak var delegate: PayrailsStoredInstrumentViewDelegate?
        public weak var presenter: PaymentPresenter?
        
        // Internal initializer used by factory method
        internal init(
            instrument: StoredInstrument,
            session: Payrails.Session?,
            style: StoredInstrumentsStyle,
            translations: StoredInstrumentsTranslations
        ) {
            self.instrument = instrument
            self.session = session
            self.style = style
            self.translations = translations
            self.containerView = UIView()
            self.labelView = UILabel()
            self.paymentButton = Payrails.StoredInstrumentPaymentButton(
                storedInstrument: instrument,
                session: session,
                translations: translations.buttonTranslations,
                style: style.buttonStyle
            )
            self.tapGestureRecognizer = UITapGestureRecognizer()
            
            super.init(frame: .zero)
            
            setupView()
        }
        
        // Required initializers with warnings
        public required init?(coder: NSCoder) {
            fatalError("Use Payrails.createStoredInstrumentView() instead")
        }
        
        private func setupView() {
            backgroundColor = style.backgroundColor
            
            // Setup container view
            containerView.backgroundColor = style.itemBackgroundColor
            containerView.layer.cornerRadius = style.itemCornerRadius
            containerView.translatesAutoresizingMaskIntoConstraints = false
            
            // Setup label
            labelView.text = getDisplayText(for: instrument)
            labelView.textColor = style.labelTextColor
            labelView.font = style.labelFont
            labelView.translatesAutoresizingMaskIntoConstraints = false
            
            // Setup payment button
            paymentButton.delegate = self
            paymentButton.translatesAutoresizingMaskIntoConstraints = false
            paymentButton.isHidden = true // Hidden by default
            
            // Setup tap gesture
            tapGestureRecognizer.addTarget(self, action: #selector(instrumentTapped))
            containerView.addGestureRecognizer(tapGestureRecognizer)
            
            // Add subviews
            addSubview(containerView)
            containerView.addSubview(labelView)
            containerView.addSubview(paymentButton)
            
            // Setup constraints
            NSLayoutConstraint.activate([
                // Container view constraints
                containerView.topAnchor.constraint(equalTo: topAnchor),
                containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
                containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
                containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
                
                // Label constraints
                labelView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: style.itemPadding.top),
                labelView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: style.itemPadding.left),
                labelView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -style.itemPadding.right),
                
                // Payment button constraints
                paymentButton.topAnchor.constraint(equalTo: labelView.bottomAnchor, constant: 8),
                paymentButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: style.itemPadding.left),
                paymentButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -style.itemPadding.right),
                paymentButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -style.itemPadding.bottom)
            ])
        }
        
        private func getDisplayText(for instrument: StoredInstrument) -> String {
            switch instrument.type {
            case .card:
                if let description = instrument.description, !description.isEmpty {
                    return "\(translations.cardPrefix) \(description)"
                } else {
                    return "Card"
                }
            case .payPal:
                if let email = instrument.email, !email.isEmpty {
                    return "\(translations.paypalPrefix) - \(email)"
                } else {
                    return translations.paypalPrefix
                }
            default:
                return instrument.description ?? "Payment Method"
            }
        }
        
        @objc private func instrumentTapped() {
            let wasSelected = isSelected
            
            if wasSelected {
                // Deselect
                setSelected(false)
                delegate?.storedInstrumentView(self, didDeselectInstrument: instrument)
            } else {
                // Select
                setSelected(true)
                delegate?.storedInstrumentView(self, didSelectInstrument: instrument)
            }
        }
        
        public func setSelected(_ selected: Bool) {
            isSelected = selected
            paymentButton.isHidden = !selected
            containerView.backgroundColor = selected ? style.selectedItemBackgroundColor : style.itemBackgroundColor
        }
        
        public func getInstrument() -> StoredInstrument {
            return instrument
        }
        
        public func setPresenter(_ presenter: PaymentPresenter?) {
            self.presenter = presenter
            paymentButton.presenter = presenter
        }
    }
}

// MARK: - PayrailsStoredInstrumentPaymentButtonDelegate
extension Payrails.StoredInstrumentView: PayrailsStoredInstrumentPaymentButtonDelegate {
    public func onPaymentButtonClicked(_ button: Payrails.StoredInstrumentPaymentButton) {
        Payrails.log("Payment button clicked for stored instrument")
    }
    
    public func onAuthorizeSuccess(_ button: Payrails.StoredInstrumentPaymentButton) {
        delegate?.storedInstrumentView(self, didCompletePaymentForInstrument: instrument)
    }
    
    public func onAuthorizeFailed(_ button: Payrails.StoredInstrumentPaymentButton) {
        // Create a generic error since we don't have specific error details
        let error = PayrailsError.authenticationError
        delegate?.storedInstrumentView(self, didFailPaymentForInstrument: instrument, error: error)
    }
}
