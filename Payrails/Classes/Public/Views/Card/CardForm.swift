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
            
            // Add border to the view
            self.layer.borderWidth = 1.0
            self.layer.borderColor = UIColor.gray.cgColor
            self.layer.cornerRadius = 8.0
            self.clipsToBounds = true
            
            // Add padding
            self.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
            self.isLayoutMarginsRelativeArrangement = true
            
            
            setupViews()
        }

        required init(coder: NSCoder) {
            fatalError(
                "Not implemented: please use init(skyflow: Skyflow.Client, config: Skyflow.Configuration)"
            )
        }

        private func setupViews() {
            let defaultStyleForContainerError = CardFormStyle.defaultStyle.errorTextStyle

            guard let container = self.containerClient.container(
                type: ContainerType.COMPOSABLE,
                options: ContainerOptions(
                    layout: config.showNameField ? [1, 1, 1, 2] : [1, 1, 2],
                    errorTextStyles: Styles(base: CardFormStyle.defaultStyle.errorTextStyle)
                )
            ) else {
                return
            }
            self.container = container
            self.cardContainer = CardCollectContainer(container: container)

            let stylesDict = config.styles ?? [:]
            let fallbackStyle = CardFormStyle.defaultStyle
            
            // Helper function to get placeholder, label, and error from translations
            func getTranslation(for fieldType: CardFieldType) -> (placeholder: String?, label: String?, errorText: String?) {
                let placeholder = config.translations?.placeholders[fieldType]
                let label = config.translations?.labels[fieldType]
                let errorText = config.translations?.error[fieldType]
                return (placeholder, label, errorText)
            }
            
            let requiredOption = CollectElementOptions(required: true)
            
            do {
                let fieldType = CardFieldType.CARD_NUMBER
                let fieldStyle = stylesDict[fieldType] ?? fallbackStyle
                let cardNumberTranslation = getTranslation(for: fieldType)
                
                let collectCardNumberInput = CollectElementInput(
                    table: tableName,
                    column: "card_number",
                    inputStyles: fieldStyle.skyflowStyles,
                    labelStyles: fieldStyle.labelStyles,
                    errorTextStyles: fieldStyle.errorStyles,
                    label: cardNumberTranslation.label ?? "Card Number",
                    placeholder: cardNumberTranslation.placeholder ?? "Card Number",
                    type: .CARD_NUMBER,
                    customErrorMessage: cardNumberTranslation.errorText
                )
                
                _ = container.create(input: collectCardNumberInput, options: requiredOption)
            }

            do {
                let fieldType = CardFieldType.CARDHOLDER_NAME
                let fieldStyle = stylesDict[fieldType] ?? fallbackStyle
                let translation = getTranslation(for: fieldType)
                
                let collectNameInput = CollectElementInput(
                    table: tableName,
                    column: "cardholder_name",
                    inputStyles: fieldStyle.skyflowStyles,
                    labelStyles: fieldStyle.labelStyles,
                    errorTextStyles: fieldStyle.errorStyles,
                    label: translation.label ?? "Card Holder Name",
                    placeholder: translation.placeholder ?? "",
                    type: .CARDHOLDER_NAME,
                    customErrorMessage: translation.errorText
                )
                
                if config.showNameField {
                    _ = container.create(input: collectNameInput, options: requiredOption)
                }
            }
            
            do {
                let fieldType = CardFieldType.CVV
                let fieldStyle = stylesDict[fieldType] ?? fallbackStyle
                let translation = getTranslation(for: fieldType)
                
                let collectCVVInput = CollectElementInput(
                    table: tableName,
                    column: "security_code",
                    inputStyles: fieldStyle.skyflowStyles,
                    labelStyles: fieldStyle.labelStyles,
                    errorTextStyles: fieldStyle.errorStyles,
                    label: translation.label ?? "CVV",
                    placeholder: translation.placeholder ??  "***",
                    type: .CVV,
                    customErrorMessage: translation.errorText
                )
                
                _ = container.create(input: collectCVVInput, options: requiredOption)
            }
            
            do {
                let fieldType = CardFieldType.EXPIRATION_MONTH
                let fieldStyle = stylesDict[fieldType] ?? fallbackStyle
                let translation = getTranslation(for: fieldType)
                
                let collectExpMonthInput = CollectElementInput(
                    table: tableName,
                    column: "expiry_month",
                    inputStyles: fieldStyle.skyflowStyles,
                    labelStyles: fieldStyle.labelStyles,
                    errorTextStyles: fieldStyle.errorStyles,
                    label: translation.label ?? "Expiration Month",
                    placeholder: translation.placeholder ?? "MM",
                    type: .EXPIRATION_MONTH,
                    customErrorMessage: translation.errorText
                )
                
                _ = container.create(input: collectExpMonthInput, options: requiredOption)
            }
            
            do{
                let fieldType = CardFieldType.EXPIRATION_MONTH
                let fieldStyle = stylesDict[fieldType] ?? fallbackStyle
                let translation = getTranslation(for: fieldType)
                
                let collectExpYearInput = CollectElementInput(
                    table: tableName,
                    column: "expiry_year",
                    inputStyles: fieldStyle.skyflowStyles,
                    labelStyles: fieldStyle.labelStyles,
                    errorTextStyles: fieldStyle.errorStyles,
                    label: translation.label ?? "Expiration Year",
                    placeholder: translation.placeholder ?? "YYYY",
                    type: .EXPIRATION_YEAR,
                    customErrorMessage: translation.errorText
                )
                
                _ = container.create(input: collectExpYearInput, options: requiredOption)
            }

            self.axis = .vertical
            self.spacing = 6

            do {
                let cardForm = try container.getComposableView()
                self.addArrangedSubview(cardForm)
            } catch {}
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
