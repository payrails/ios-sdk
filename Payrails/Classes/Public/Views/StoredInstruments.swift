import UIKit

public protocol PayrailsStoredInstrumentsDelegate: AnyObject {
    func storedInstruments(_ view: Payrails.StoredInstruments, didSelectInstrument instrument: StoredInstrument)
    func storedInstruments(_ view: Payrails.StoredInstruments, didCompletePaymentForInstrument instrument: StoredInstrument)
    func storedInstruments(_ view: Payrails.StoredInstruments, didFailPaymentForInstrument instrument: StoredInstrument, error: PayrailsError)
    func storedInstruments(_ view: Payrails.StoredInstruments, didRequestDeleteInstrument instrument: StoredInstrument)
    func storedInstruments(_ view: Payrails.StoredInstruments, didRequestUpdateInstrument instrument: StoredInstrument)
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

public struct DeleteButtonStyle {
    public let backgroundColor: UIColor
    public let textColor: UIColor
    public let font: UIFont
    public let cornerRadius: CGFloat
    public let size: CGSize
    
    public init(
        backgroundColor: UIColor = .systemRed,
        textColor: UIColor = .white,
        font: UIFont = .systemFont(ofSize: 14),
        cornerRadius: CGFloat = 4,
        size: CGSize = CGSize(width: 32, height: 32)
    ) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.font = font
        self.cornerRadius = cornerRadius
        self.size = size
    }
    
    public static let defaultStyle = DeleteButtonStyle()
}

public struct UpdateButtonStyle {
    public let backgroundColor: UIColor
    public let textColor: UIColor
    public let font: UIFont
    public let cornerRadius: CGFloat
    public let size: CGSize
    
    public init(
        backgroundColor: UIColor = .systemBlue,
        textColor: UIColor = .white,
        font: UIFont = .systemFont(ofSize: 14),
        cornerRadius: CGFloat = 4,
        size: CGSize = CGSize(width: 32, height: 32)
    ) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.font = font
        self.cornerRadius = cornerRadius
        self.size = size
    }
    
    public static let defaultStyle = UpdateButtonStyle()
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
    public let deleteButtonStyle: DeleteButtonStyle
    public let updateButtonStyle: UpdateButtonStyle
    
    public init(
        backgroundColor: UIColor = .clear,
        itemBackgroundColor: UIColor = .systemBackground,
        selectedItemBackgroundColor: UIColor = .systemGray6,
        labelTextColor: UIColor = .label,
        labelFont: UIFont = .systemFont(ofSize: 16),
        itemCornerRadius: CGFloat = 8,
        itemSpacing: CGFloat = 8,
        itemPadding: UIEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16),
        buttonStyle: StoredInstrumentButtonStyle = .defaultStyle,
        deleteButtonStyle: DeleteButtonStyle = .defaultStyle,
        updateButtonStyle: UpdateButtonStyle = .defaultStyle
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
        self.deleteButtonStyle = deleteButtonStyle
        self.updateButtonStyle = updateButtonStyle
    }
    
    public static let defaultStyle = StoredInstrumentsStyle()
}



public extension Payrails {
    final class StoredInstruments: UIView {
        private weak var session: Payrails.Session?
        private let style: StoredInstrumentsStyle
        private let translations: StoredInstrumentsTranslations
        private let showDeleteButton: Bool
        private let showUpdateButton: Bool
        private let showPayButton: Bool
        private var instrumentViews: [Payrails.StoredInstrumentView] = []
        private var selectedInstrumentId: String?
        private let stackView: UIStackView
        
        public weak var delegate: PayrailsStoredInstrumentsDelegate?
        public weak var presenter: PaymentPresenter?
        
        // Internal initializer used by factory method
        internal init(
            session: Payrails.Session?,
            style: StoredInstrumentsStyle,
            translations: StoredInstrumentsTranslations,
            showDeleteButton: Bool = false,
            showUpdateButton: Bool = false,
            showPayButton: Bool = false
        ) {
            self.session = session
            self.style = style
            self.translations = translations
            self.showDeleteButton = showDeleteButton
            self.showUpdateButton = showUpdateButton
            self.showPayButton = showPayButton
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
                createInstrumentView(for: instrument, showDeleteButton: showDeleteButton, showUpdateButton: showUpdateButton, showPayButton: showPayButton)
            }
        }
        
        private func createInstrumentView(for instrument: StoredInstrument, showDeleteButton: Bool = false, showUpdateButton: Bool = false, showPayButton: Bool = false) {
            // Create StoredInstrumentView using the new component
            let instrumentView = Payrails.StoredInstrumentView(
                instrument: instrument,
                session: session,
                style: style,
                translations: translations,
                showDeleteButton: showDeleteButton,
                showUpdateButton: showUpdateButton,
                showPayButton: showPayButton
            )
            
            instrumentView.delegate = self
            instrumentView.presenter = presenter
            instrumentView.translatesAutoresizingMaskIntoConstraints = false
            
            instrumentViews.append(instrumentView)
            stackView.addArrangedSubview(instrumentView)
        }
        

        
        public func refreshInstruments() {
            // Clear existing views
            for instrumentView in instrumentViews {
                stackView.removeArrangedSubview(instrumentView)
                instrumentView.removeFromSuperview()
            }
            instrumentViews.removeAll()
            selectedInstrumentId = nil
            
            // Reload instruments
            loadStoredInstruments()
        }
    }
}

// MARK: - PayrailsStoredInstrumentViewDelegate
extension Payrails.StoredInstruments: PayrailsStoredInstrumentViewDelegate {
    public func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didSelectInstrument instrument: StoredInstrument) {
        // Deselect all other instrument views
        for instrumentView in instrumentViews {
            if instrumentView != view {
                instrumentView.setSelected(false)
            }
        }
        
        selectedInstrumentId = instrument.id
        delegate?.storedInstruments(self, didSelectInstrument: instrument)
    }
    
    public func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didDeselectInstrument instrument: StoredInstrument) {
        selectedInstrumentId = nil
        // Note: We don't forward deselection to the main delegate as it only has selection callback
    }
    
    public func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didCompletePaymentForInstrument instrument: StoredInstrument) {
        delegate?.storedInstruments(self, didCompletePaymentForInstrument: instrument)
    }
    
    public func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didFailPaymentForInstrument instrument: StoredInstrument, error: PayrailsError) {
        delegate?.storedInstruments(self, didFailPaymentForInstrument: instrument, error: error)
    }
    
    public func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didRequestDeleteInstrument instrument: StoredInstrument) {
        delegate?.storedInstruments(self, didRequestDeleteInstrument: instrument)
    }
    
    public func storedInstrumentView(_ view: Payrails.StoredInstrumentView, didRequestUpdateInstrument instrument: StoredInstrument) {
        delegate?.storedInstruments(self, didRequestUpdateInstrument: instrument)
    }
}
