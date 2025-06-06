import UIKit

public protocol PayrailsStoredInstrumentViewDelegate: AnyObject {
    func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didSelectInstrument instrument: StoredInstrument)
    func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didDeselectInstrument instrument: StoredInstrument)
    func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didCompletePaymentForInstrument instrument: StoredInstrument)
    func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didFailPaymentForInstrument instrument: StoredInstrument, error: PayrailsError)
    func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didRequestDeleteInstrument instrument: StoredInstrument)
}

public extension Payrails {
    final class StoredInstrumentView: UIView {
        private let instrument: StoredInstrument
        private weak var session: Payrails.Session?
        private let style: StoredInstrumentsStyle
        private let translations: StoredInstrumentsTranslations
        private let showDeleteButton: Bool
        private let showPayButton: Bool
        private let containerView: UIView
        private let labelView: UILabel
        private let paymentButton: Payrails.CardPaymentButton
        private let deleteButton: UIButton
        private let tapGestureRecognizer: UITapGestureRecognizer
        private var isSelected: Bool = false
        
        public weak var delegate: PayrailsStoredInstrumentViewDelegate?
        public weak var presenter: PaymentPresenter?
        
        // Internal initializer used by factory method
        internal init(
            instrument: StoredInstrument,
            session: Payrails.Session?,
            style: StoredInstrumentsStyle,
            translations: StoredInstrumentsTranslations,
            showDeleteButton: Bool = false,
            showPayButton: Bool = false
        ) {
            self.instrument = instrument
            self.session = session
            self.style = style
            self.translations = translations
            self.showDeleteButton = showDeleteButton
            self.showPayButton = showPayButton
            self.containerView = UIView()
            self.labelView = UILabel()
            // Use unified CardPaymentButton in stored instrument mode
            self.paymentButton = Payrails.CardPaymentButton(
                storedInstrument: instrument,
                session: session,
                translations: CardPaymenButtonTranslations(label: translations.buttonTranslations.label),
                storedInstrumentTranslations: translations.buttonTranslations,
                buttonStyle: style.buttonStyle
            )
            self.deleteButton = UIButton(type: .custom)
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
            paymentButton.presenter = self.presenter
            
            // Setup delete button
            setupDeleteButton()
            
            // Setup tap gesture
            tapGestureRecognizer.addTarget(self, action: #selector(instrumentTapped))
            containerView.addGestureRecognizer(tapGestureRecognizer)
            
            // Add subviews
            addSubview(containerView)
            containerView.addSubview(labelView)
            if showPayButton {
                containerView.addSubview(paymentButton)
            }
            if showDeleteButton {
                containerView.addSubview(deleteButton)
            }
            
            // Setup constraints
            setupConstraints()
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
            if showPayButton {
                paymentButton.isHidden = !selected
            }
            containerView.backgroundColor = selected ? style.selectedItemBackgroundColor : style.itemBackgroundColor
        }
        
        public func getInstrument() -> StoredInstrument {
            return instrument
        }
        
        public func setPresenter(_ presenter: PaymentPresenter?) {
            self.presenter = presenter
            paymentButton.presenter = presenter
        }
        
        private func setupDeleteButton() {
            deleteButton.setTitle("🗑️", for: .normal)
            deleteButton.titleLabel?.font = style.deleteButtonStyle.font
            deleteButton.backgroundColor = style.deleteButtonStyle.backgroundColor
            deleteButton.setTitleColor(style.deleteButtonStyle.textColor, for: .normal)
            deleteButton.layer.cornerRadius = style.deleteButtonStyle.cornerRadius
            deleteButton.translatesAutoresizingMaskIntoConstraints = false
            deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
            deleteButton.isHidden = !showDeleteButton
        }
        
        private func setupConstraints() {
            var constraints: [NSLayoutConstraint] = [
                // Container view constraints
                containerView.topAnchor.constraint(equalTo: topAnchor),
                containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
                containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
                containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
                
                // Label constraints
                labelView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: style.itemPadding.top),
                labelView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: style.itemPadding.left)
            ]
            
            // Payment button constraints (only if showPayButton is true)
            if showPayButton {
                constraints.append(contentsOf: [
                    paymentButton.topAnchor.constraint(equalTo: labelView.bottomAnchor, constant: 8),
                    paymentButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: style.itemPadding.left),
                    paymentButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -style.itemPadding.right),
                    paymentButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -style.itemPadding.bottom)
                ])
            } else {
                // If no payment button, label should be connected to bottom
                constraints.append(labelView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -style.itemPadding.bottom))
            }
            
            if showDeleteButton {
                // Adjust label trailing constraint to make room for delete button
                constraints.append(labelView.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8))
                
                // Delete button constraints
                constraints.append(contentsOf: [
                    deleteButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: style.itemPadding.top),
                    deleteButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -style.itemPadding.right),
                    deleteButton.widthAnchor.constraint(equalToConstant: style.deleteButtonStyle.size.width),
                    deleteButton.heightAnchor.constraint(equalToConstant: style.deleteButtonStyle.size.height)
                ])
            } else {
                // No delete button, label can use full width
                constraints.append(labelView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -style.itemPadding.right))
            }
            
            NSLayoutConstraint.activate(constraints)
        }
        
        @objc private func deleteButtonTapped() {
            delegate?.storedInstrumentView(self, didRequestDeleteInstrument: instrument)
        }
    }
}

// MARK: - PayrailsCardPaymentButtonDelegate
extension Payrails.StoredInstrumentView: PayrailsCardPaymentButtonDelegate {
    public func onPaymentButtonClicked(_ button: Payrails.CardPaymentButton) {
        Payrails.log("Payment button clicked for stored instrument")
    }
    
    public func onAuthorizeSuccess(_ button: Payrails.CardPaymentButton) {
        delegate?.storedInstrumentView(self, didCompletePaymentForInstrument: instrument)
    }
    
    public func onThreeDSecureChallenge(_ button: Payrails.CardPaymentButton) {
        // 3DS is not applicable for stored instruments, but required by protocol
        Payrails.log("3DS challenge called for stored instrument (unexpected)")
    }
    
    public func onAuthorizeFailed(_ button: Payrails.CardPaymentButton) {
        // Create a generic error since we don't have specific error details
        let error = PayrailsError.authenticationError
        delegate?.storedInstrumentView(self, didFailPaymentForInstrument: instrument, error: error)
    }
}
