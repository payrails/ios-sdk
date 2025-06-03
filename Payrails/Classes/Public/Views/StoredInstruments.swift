import UIKit

public protocol PayrailsStoredInstrumentsDelegate: AnyObject {
    func storedInstruments(_ view: Payrails.StoredInstruments, didSelectInstrument instrument: StoredInstrument)
    func storedInstruments(_ view: Payrails.StoredInstruments, didCompletePaymentForInstrument instrument: StoredInstrument)
    func storedInstruments(_ view: Payrails.StoredInstruments, didFailPaymentForInstrument instrument: StoredInstrument, error: PayrailsError)
}

public struct StoredInstrumentsTranslations {
    public let cardPrefix: String
    public let paypalPrefix: String
    public let buttonTranslations: StoredInstrumentButtonTranslations
    
    public init(
        cardPrefix: String = "Card ending in",
        paypalPrefix: String = "PayPal",
        buttonTranslations: StoredInstrumentButtonTranslations = StoredInstrumentButtonTranslations()
    ) {
        self.cardPrefix = cardPrefix
        self.paypalPrefix = paypalPrefix
        self.buttonTranslations = buttonTranslations
    }
}

public struct StoredInstrumentsStyle {
    public let backgroundColor: UIColor
    public let itemBackgroundColor: UIColor
    public let selectedItemBackgroundColor: UIColor
    public let labelTextColor: UIColor
    public let labelFont: UIFont
    public let itemCornerRadius: CGFloat
    public let itemSpacing: CGFloat
    public let itemPadding: UIEdgeInsets
    public let buttonStyle: StoredInstrumentButtonStyle
    
    public init(
        backgroundColor: UIColor = .clear,
        itemBackgroundColor: UIColor = .systemBackground,
        selectedItemBackgroundColor: UIColor = .systemGray6,
        labelTextColor: UIColor = .label,
        labelFont: UIFont = .systemFont(ofSize: 16),
        itemCornerRadius: CGFloat = 8,
        itemSpacing: CGFloat = 8,
        itemPadding: UIEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16),
        buttonStyle: StoredInstrumentButtonStyle = .defaultStyle
    ) {
        self.backgroundColor = backgroundColor
        self.itemBackgroundColor = itemBackgroundColor
        self.selectedItemBackgroundColor = selectedItemBackgroundColor
        self.labelTextColor = labelTextColor
        self.labelFont = labelFont
        self.itemCornerRadius = itemCornerRadius
        self.itemSpacing = itemSpacing
        self.itemPadding = itemPadding
        self.buttonStyle = buttonStyle
    }
    
    public static let defaultStyle = StoredInstrumentsStyle()
}

private struct InstrumentItemView {
    let instrument: StoredInstrument
    let containerView: UIView
    let labelView: UILabel
    let paymentButton: Payrails.StoredInstrumentPaymentButton
    let tapGestureRecognizer: UITapGestureRecognizer
}

public extension Payrails {
    final class StoredInstruments: UIView {
        private weak var session: Payrails.Session?
        private let style: StoredInstrumentsStyle
        private let translations: StoredInstrumentsTranslations
        private var instrumentViews: [InstrumentItemView] = []
        private var selectedInstrumentId: String?
        private let stackView: UIStackView
        
        public weak var delegate: PayrailsStoredInstrumentsDelegate?
        public weak var presenter: PaymentPresenter?
        
        // Internal initializer used by factory method
        internal init(
            session: Payrails.Session?,
            style: StoredInstrumentsStyle,
            translations: StoredInstrumentsTranslations
        ) {
            self.session = session
            self.style = style
            self.translations = translations
            self.stackView = UIStackView()
            
            super.init(frame: .zero)
            
            setupView()
            loadStoredInstruments()
        }
        
        // Required initializers with warnings
        public required init?(coder: NSCoder) {
            fatalError("Use Payrails.createStoredInstruments() instead")
        }
        
        private func setupView() {
            backgroundColor = style.backgroundColor
            
            // Setup stack view
            stackView.axis = .vertical
            stackView.spacing = style.itemSpacing
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            addSubview(stackView)
            
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: topAnchor),
                stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
                stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
        
        private func loadStoredInstruments() {
            guard let session = session else {
                Payrails.log("Session not available for loading stored instruments")
                return
            }
            
            // Get all stored instruments (both card and PayPal)
            let cardInstruments = session.storedInstruments(for: .card)
            let paypalInstruments = session.storedInstruments(for: .payPal)
            let allInstruments = cardInstruments + paypalInstruments
            
            // If no instruments, render nothing (as requested)
            guard !allInstruments.isEmpty else {
                return
            }
            
            // Create views for each instrument
            for instrument in allInstruments {
                createInstrumentView(for: instrument)
            }
        }
        
        private func createInstrumentView(for instrument: StoredInstrument) {
            // Create container view
            let containerView = UIView()
            containerView.backgroundColor = style.itemBackgroundColor
            containerView.layer.cornerRadius = style.itemCornerRadius
            containerView.translatesAutoresizingMaskIntoConstraints = false
            
            // Create label
            let label = UILabel()
            label.text = getDisplayText(for: instrument)
            label.textColor = style.labelTextColor
            label.font = style.labelFont
            label.translatesAutoresizingMaskIntoConstraints = false
            
            // Create payment button
            let paymentButton = Payrails.StoredInstrumentPaymentButton(
                storedInstrument: instrument,
                session: session,
                translations: translations.buttonTranslations,
                style: style.buttonStyle
            )
            paymentButton.delegate = self
            paymentButton.presenter = presenter
            paymentButton.translatesAutoresizingMaskIntoConstraints = false
            paymentButton.isHidden = true // Hidden by default
            
            // Create tap gesture
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(instrumentTapped(_:)))
            containerView.addGestureRecognizer(tapGesture)
            
            // Add subviews
            containerView.addSubview(label)
            containerView.addSubview(paymentButton)
            
            // Setup constraints
            NSLayoutConstraint.activate([
                // Label constraints
                label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: style.itemPadding.top),
                label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: style.itemPadding.left),
                label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -style.itemPadding.right),
                
                // Payment button constraints
                paymentButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
                paymentButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: style.itemPadding.left),
                paymentButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -style.itemPadding.right),
                paymentButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -style.itemPadding.bottom)
            ])
            
            // Create item view struct
            let itemView = InstrumentItemView(
                instrument: instrument,
                containerView: containerView,
                labelView: label,
                paymentButton: paymentButton,
                tapGestureRecognizer: tapGesture
            )
            
            instrumentViews.append(itemView)
            stackView.addArrangedSubview(containerView)
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
        
        @objc private func instrumentTapped(_ gesture: UITapGestureRecognizer) {
            guard let containerView = gesture.view,
                  let itemView = instrumentViews.first(where: { $0.containerView == containerView }) else {
                return
            }
            
            let instrument = itemView.instrument
            let isCurrentlySelected = selectedInstrumentId == instrument.id
            
            // Hide all payment buttons and reset background colors
            for view in instrumentViews {
                view.paymentButton.isHidden = true
                view.containerView.backgroundColor = style.itemBackgroundColor
            }
            
            if !isCurrentlySelected {
                // Show this instrument's payment button and highlight
                itemView.paymentButton.isHidden = false
                itemView.containerView.backgroundColor = style.selectedItemBackgroundColor
                selectedInstrumentId = instrument.id
                
                // Notify delegate
                delegate?.storedInstruments(self, didSelectInstrument: instrument)
            } else {
                // Deselect
                selectedInstrumentId = nil
            }
        }
        
        public func refreshInstruments() {
            // Clear existing views
            for itemView in instrumentViews {
                stackView.removeArrangedSubview(itemView.containerView)
                itemView.containerView.removeFromSuperview()
            }
            instrumentViews.removeAll()
            selectedInstrumentId = nil
            
            // Reload instruments
            loadStoredInstruments()
        }
    }
}

// MARK: - PayrailsStoredInstrumentPaymentButtonDelegate
extension Payrails.StoredInstruments: PayrailsStoredInstrumentPaymentButtonDelegate {
    public func onPaymentButtonClicked(_ button: Payrails.StoredInstrumentPaymentButton) {
        Payrails.log("Payment button clicked for stored instrument")
    }
    
    public func onAuthorizeSuccess(_ button: Payrails.StoredInstrumentPaymentButton) {
        let instrument = button.getStoredInstrument()
        delegate?.storedInstruments(self, didCompletePaymentForInstrument: instrument)
    }
    
    public func onAuthorizeFailed(_ button: Payrails.StoredInstrumentPaymentButton) {
        let instrument = button.getStoredInstrument()
        // Create a generic error since we don't have specific error details
        let error = PayrailsError.authenticationError
        delegate?.storedInstruments(self, didFailPaymentForInstrument: instrument, error: error)
    }
}
