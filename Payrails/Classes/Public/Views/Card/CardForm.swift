import UIKit
import PayrailsCSE

// Protocol for CardForm delegate
public protocol PayrailsCardFormDelegate: AnyObject {
    func cardForm(_ view: Payrails.CardForm, didCollectCardData data: String)
    func cardForm(_ view: Payrails.CardForm, didFailWithError error: Error)
}

// Extension to Payrails for CardForm
public extension Payrails {
    
    final class CardCollectContainer: CardContainer {
        public let container: Container<ComposableContainer>

        public init(container: Container<ComposableContainer>) {
            self.container = container
        }

        public func collect(with callback: Callback) {
            container.collect(
                callback: callback
            )
        }
    }

    class CardForm: UIStackView {
        public weak var delegate: PayrailsCardFormDelegate?

        private let config: CardFormConfig
        private let containerClient: Client
        private var container: Container<ComposableContainer>?
        private let tableName: String
        private let holderReference: String
        public var cardContainer: CardCollectContainer?
        private var payrailsCSE: PayrailsCSE?
        
        public init(
            config: CardFormConfig,
            tableName: String,
            cseConfig: (data: String, version: String),
            holderReference: String,
            cseInstance: PayrailsCSE
        ) {
            self.containerClient = Client()
            self.config = config
            // this is also skyflow leftover
            self.tableName = tableName
            self.holderReference = holderReference
            self.payrailsCSE = cseInstance
            
            super.init(frame: .zero)

            // Apply wrapper styles from config, falling back to defaults
            let stylesConfig = config.styles ?? CardFormStylesConfig.defaultConfig
            let wrapperStyle = stylesConfig.wrapperStyle ?? CardWrapperStyle.defaultStyle

            // Apply styles to the view's layer and layout margins
            if let bgColor = wrapperStyle.backgroundColor {
                self.backgroundColor = bgColor // Apply background color to the view itself
            }
            if let borderColor = wrapperStyle.borderColor {
                self.layer.borderColor = borderColor.cgColor
            }
            if let borderWidth = wrapperStyle.borderWidth {
                self.layer.borderWidth = borderWidth
            }
            if let cornerRadius = wrapperStyle.cornerRadius {
                self.layer.cornerRadius = cornerRadius
                self.clipsToBounds = true // Ensure content is clipped if corner radius is set
            } else {
                self.clipsToBounds = false // No corner radius, no need to clip
            }
            
            // Apply padding (layout margins)
            if let padding = wrapperStyle.padding {
                self.layoutMargins = padding
            }
            self.isLayoutMarginsRelativeArrangement = true // Always true if using layoutMargins
            
            setupViews()
        }

        required init(coder: NSCoder) {
            fatalError(
                "Not implemented: please use init(skyflow: Skyflow.Client, config: Skyflow.Configuration)"
            )
        }

        private func setupViews() {
            // Use the new styles config, falling back to its default
            let stylesConfig = config.styles ?? CardFormStylesConfig.defaultConfig
            // let defaultInputStyle = CardFieldSpecificStyles.defaultStyle // No longer needed directly here
            let defaultLabelStyle = CardStyle(textColor: .darkGray) // Match default from CardFormStylesConfig
            let defaultErrorStyle = CardStyle(textColor: .red) // Match default from CardFormStylesConfig

            // Get the shared error text style
            let containerErrorStyle = stylesConfig.errorTextStyle ?? defaultErrorStyle

            guard let container = self.containerClient.container(
                type: ContainerType.COMPOSABLE,
                options: ContainerOptions(
                    layout: config.showNameField ? [1, 1, 1, 2] : [1, 1, 2], // Layout depends on showing name field
                    // Use the errorTextStyle from the new config for the container
                    errorTextStyles: Styles(base: containerErrorStyle)
                )
            ) else {
                print("Failed to create Composable Container") // Added log
                return
            }
            self.container = container
            self.cardContainer = CardCollectContainer(container: container)

            // Helper function to get placeholder, label, and error from translations
            func getTranslation(for fieldType: CardFieldType) -> (placeholder: String?, label: String?, errorText: String?) {
                // Use optional chaining for safety
                let placeholder = config.translations?.placeholders[fieldType]
                let label = config.translations?.labels[fieldType]
                let errorText = config.translations?.error[fieldType]
                return (placeholder, label, errorText)
            }
            
            let requiredOption = CollectElementOptions(required: true)
            
            // --- Card Number Field ---
            do {
                let fieldType = CardFieldType.CARD_NUMBER
                let translation = getTranslation(for: fieldType)
                
                // Get effective styles using the helper method
                let inputStyle = stylesConfig.effectiveInputStyles(for: fieldType)
                let labelStyle = stylesConfig.labelStyles?[fieldType] ?? defaultLabelStyle
                // Error style is shared
                
                let collectCardNumberInput = CollectElementInput(
                    table: tableName,
                    column: "card_number",
                    inputStyles: inputStyle.skyflowStyles, // Use helper from CardFieldSpecificStyles
                    labelStyles: Styles(base: labelStyle), // Wrap single style
                    errorTextStyles: Styles(base: containerErrorStyle), // Use shared error style
                    label: translation.label ?? "", // Use provided label or empty string
                    placeholder: translation.placeholder ?? "•••• •••• •••• ••••", // Default placeholder
                    type: .CARD_NUMBER,
                    customErrorMessage: translation.errorText
                )
                
                _ = container.create(input: collectCardNumberInput, options: requiredOption)
            }

            // --- Cardholder Name Field (Conditional) ---
            if config.showNameField {
                do {
                    let fieldType = CardFieldType.CARDHOLDER_NAME
                    let translation = getTranslation(for: fieldType)
                    
                    // Get effective styles using the helper method
                    let inputStyle = stylesConfig.effectiveInputStyles(for: fieldType)
                    let labelStyle = stylesConfig.labelStyles?[fieldType] ?? defaultLabelStyle
                    // Error style is shared
                    
                    let collectNameInput = CollectElementInput(
                        table: tableName,
                        column: "cardholder_name",
                        inputStyles: inputStyle.skyflowStyles,
                        labelStyles: Styles(base: labelStyle),
                        errorTextStyles: Styles(base: containerErrorStyle),
                        label: translation.label ?? "", // Use provided label or empty string
                        placeholder: translation.placeholder ?? "Full Name", // Default placeholder
                        type: .CARDHOLDER_NAME,
                        customErrorMessage: translation.errorText
                    )
                    
                    _ = container.create(input: collectNameInput, options: requiredOption)
                }
            }
            
            // --- CVV Field ---
            do {
                let fieldType = CardFieldType.CVV
                let translation = getTranslation(for: fieldType)

                // Get effective styles using the helper method
                let inputStyle = stylesConfig.effectiveInputStyles(for: fieldType)
                let labelStyle = stylesConfig.labelStyles?[fieldType] ?? defaultLabelStyle
                // Error style is shared

                let collectCVVInput = CollectElementInput(
                    table: tableName,
                    column: "security_code",
                    inputStyles: inputStyle.skyflowStyles,
                    labelStyles: Styles(base: labelStyle),
                    errorTextStyles: Styles(base: containerErrorStyle),
                    label: translation.label ?? "", // Use provided label or empty string
                    placeholder: translation.placeholder ?? "•••", // Default placeholder
                    type: .CVV,
                    customErrorMessage: translation.errorText
                )
                
                _ = container.create(input: collectCVVInput, options: requiredOption)
            }
            
            // --- Expiration Month Field ---
            // Note: Skyflow often uses EXPIRATION_DATE for combined MM/YY or separate MM and YY.
            // Assuming separate fields based on original code. Adjust if using combined field.
            do {
                let fieldType = CardFieldType.EXPIRATION_MONTH
                let translation = getTranslation(for: fieldType)

                // Get effective styles using the helper method
                // Note: Label fallback logic remains the same
                let inputStyle = stylesConfig.effectiveInputStyles(for: fieldType) // Use helper
                let labelStyle = stylesConfig.labelStyles?[fieldType] ?? stylesConfig.labelStyles?[.EXPIRATION_DATE] ?? defaultLabelStyle
                 // Error style is shared

                let collectExpMonthInput = CollectElementInput(
                    table: tableName,
                    column: "expiry_month",
                    inputStyles: inputStyle.skyflowStyles,
                    labelStyles: Styles(base: labelStyle),
                    errorTextStyles: Styles(base: containerErrorStyle),
                    label: translation.label ?? "", // Use provided label or empty string
                    placeholder: translation.placeholder ?? "MM", // Default placeholder
                    type: .EXPIRATION_MONTH,
                    customErrorMessage: translation.errorText
                )
                
                _ = container.create(input: collectExpMonthInput, options: requiredOption)
            }
            
            // --- Expiration Year Field ---
            do {
                let fieldType = CardFieldType.EXPIRATION_YEAR
                let translation = getTranslation(for: fieldType)

                // Get effective styles using the helper method
                // Note: Label fallback logic remains the same
                let inputStyle = stylesConfig.effectiveInputStyles(for: fieldType) // Use helper
                let labelStyle = stylesConfig.labelStyles?[fieldType] ?? stylesConfig.labelStyles?[.EXPIRATION_DATE] ?? defaultLabelStyle
                // Error style is shared

                let collectExpYearInput = CollectElementInput(
                    table: tableName,
                    column: "expiry_year",
                    inputStyles: inputStyle.skyflowStyles,
                    labelStyles: Styles(base: labelStyle),
                    errorTextStyles: Styles(base: containerErrorStyle),
                    label: translation.label ?? "", // Use provided label or empty string
                    placeholder: translation.placeholder ?? "YYYY", // Default placeholder
                    type: .EXPIRATION_YEAR,
                    customErrorMessage: translation.errorText
                )
                
                _ = container.create(input: collectExpYearInput, options: requiredOption)
            }

            container.setupDynamicCVVLengthHandling()
            
            // --- StackView Configuration ---
            self.axis = .vertical
            self.spacing = 10 // Adjusted spacing slightly

            // --- Add Composable View ---
            do {
                let composableView = try container.getComposableView()
                self.addArrangedSubview(composableView)
            } catch {
                print("Error getting composable view: \(error)") // Added error handling
            }
        }

        public class CardCollectCallback: Callback {
            var onSuccess: ((Any) -> Void)?
            var onFailure: ((Any) -> Void)?
            
            public func onSuccess(_ responseBody: Any) {
                onSuccess?(responseBody)
            }
            
            public func onFailure(_ error: Any) {
                onFailure?(error)
            }
        }
        
        public func collectFields() {
            guard let container = self.container else { return }
            
            // Create a callback to handle the collected data
            let callback = CardCollectCallback()
            var encryptedCardData: String?
            
            callback.onSuccess = { [weak self] responseBody in
                guard let self = self else { return }

                if let response = responseBody as? [String: Any],
                   let records = response["records"] as? [[String: Any]],
                   let firstRecord = records.first,
                   let fields = firstRecord["fields"] as? [String: Any],
                   let cardNumber = fields["card_number"] as? String,
                   let expiryMonth = fields["expiry_month"] as? String,
                   let expiryYear = fields["expiry_year"] as? String,
                   let securityCode = fields["security_code"] as? String {
                   
                    // Create card object
                    let payrailsCard = Card(
                        holderReference: self.holderReference,
                        cardNumber: cardNumber,
                        expiryMonth: expiryMonth,
                        expiryYear: expiryYear,
                        holderName: "nil sasds",
                        securityCode: securityCode
                    )
                    
                    do {
                        if let payrailsCSE = self.payrailsCSE {
                            encryptedCardData = try payrailsCSE.encryptCardData(card: payrailsCard)
                            DispatchQueue.main.async {
                                self.delegate?.cardForm(self, didCollectCardData: encryptedCardData ?? "")
                            }
                        }
                    } catch {
                        print("Failed to encrypt card data:", error)
                        DispatchQueue.main.async {
                            self.delegate?.cardForm(self, didFailWithError: error)
                        }
                    }
                }
            }
            
            callback.onFailure = { error in
                print("Failed to collect card data:", error)
            }
            
            // Perform collection
            cardContainer?.collect(with: callback)
        }
    }
}
