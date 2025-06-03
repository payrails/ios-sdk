import UIKit
import PassKit

public extension Payrails {
    final class ApplePayButtonWithToggle: ApplePayElement {
        private let applePayButton: ApplePayButton
        private let saveInstrumentToggle = UISwitch()
        private let saveInstrumentLabel = UILabel()
        private let stackView = UIStackView()
        
        override public var saveInstrument: Bool {
            get { return saveInstrumentToggle.isOn }
            set { 
                saveInstrumentToggle.isOn = newValue
                applePayButton.saveInstrument = newValue
            }
        }
        
        override public var delegate: PayrailsApplePayButtonDelegate? {
            didSet {
                applePayButton.delegate = delegate
            }
        }
        
        override public var presenter: PaymentPresenter? {
            didSet {
                applePayButton.presenter = presenter
            }
        }
        
        override public var isEnabled: Bool {
            didSet {
                applePayButton.isEnabled = isEnabled
                saveInstrumentToggle.isEnabled = isEnabled
                saveInstrumentLabel.alpha = isEnabled ? 1.0 : 0.5
            }
        }
        
        internal override init(session: Payrails.Session?) {
            guard let session = session else {
                fatalError("ApplePayButtonWithToggle requires a valid session")
            }
            self.applePayButton = ApplePayButton(session: session, type: .plain, style: .black)
            super.init(session: session)
            setupViews(showSaveInstrument: false)
        }
        
        init(session: Payrails.Session?, showSaveInstrument: Bool, type: PKPaymentButtonType = .plain, style: PKPaymentButtonStyle = .black) {
            guard let session = session else {
                fatalError("ApplePayButtonWithToggle requires a valid session")
            }
            self.applePayButton = ApplePayButton(session: session, type: type, style: style)
            super.init(session: session)
            setupViews(showSaveInstrument: showSaveInstrument)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupViews(showSaveInstrument: Bool) {
            // Configure main stack view
            stackView.axis = .vertical
            stackView.spacing = 8
            stackView.alignment = .fill
            stackView.distribution = .fill
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            // Add Apple Pay button to stack
            stackView.addArrangedSubview(applePayButton)
            
            if showSaveInstrument {
                setupSaveInstrumentToggle()
            }
            
            // Add stack view to self
            addSubview(stackView)
            
            // Setup constraints
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: topAnchor),
                stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
                stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
        
        private func setupSaveInstrumentToggle() {
            // Configure label
            saveInstrumentLabel.text = "Save instrument"
            saveInstrumentLabel.font = UIFont.systemFont(ofSize: 14)
            saveInstrumentLabel.textColor = .darkGray
            
            // Create toggle container
            let toggleContainer = UIStackView()
            toggleContainer.axis = .horizontal
            toggleContainer.spacing = 8
            toggleContainer.alignment = .center
            
            // Add toggle and label to container
            toggleContainer.addArrangedSubview(saveInstrumentLabel)
            toggleContainer.addArrangedSubview(saveInstrumentToggle)
            
            // Add toggle container to main stack
            stackView.addArrangedSubview(toggleContainer)
            
            // Link toggle to button
            saveInstrumentToggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        }
        
        @objc private func toggleChanged() {
            // Update the internal button's save state
            applePayButton.saveInstrument = saveInstrumentToggle.isOn
            self.saveInstrument = saveInstrumentToggle.isOn
        }
        
        // Override executePayment to delegate to the internal ApplePayButton
        override internal func executePayment() {
            applePayButton.executePayment()
        }
    }
}
