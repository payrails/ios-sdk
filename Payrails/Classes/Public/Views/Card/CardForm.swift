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
    //jo
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
            // this is a workaround just for skyflow to work, we don't need it
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
            guard let container = self.containerClient.container(
                type: ContainerType.COMPOSABLE,
                options: ContainerOptions(
                    layout: config.showNameField ? [1, 1, 1, 2] : [1, 1, 2],
                    errorTextStyles: Styles(base: config.style.errorTextStyle)
                )
            ) else {
                return
            }
            self.container = container
            self.cardContainer = CardCollectContainer(container: container)

            let styles: Styles = config.style.skyflowStyles
            
            // Helper function to get placeholder, label, and error from translations
            func getTranslation(for fieldType: CardFieldType) -> (placeholder: String?, label: String?, errorText: String?) {
                let placeholder = config.translations?.placeholders[fieldType]
                let label = config.translations?.labels[fieldType]
                let errorText = config.translations?.error[fieldType] 
                return (placeholder, label, errorText)
            }
            
            // Get translations for CARD_NUMBER
            let cardNumberTranslation = getTranslation(for: .CARD_NUMBER)
            let collectCardNumberInput = CollectElementInput(
                table: tableName,
                column: "card_number",
                inputStyles: config.fieldConfig(for: .CARD_NUMBER)?.style?.skyflowStyles ?? styles,
                labelStyles: config.style.labelStyles,
                errorTextStyles: config.style.errorStyles,
                label: cardNumberTranslation.label ?? config.fieldConfig(for: .CARD_NUMBER)?.title ?? "Card Number",
                placeholder: cardNumberTranslation.placeholder ?? config.fieldConfig(for: .CARD_NUMBER)?.placeholder ?? "Card Number",
                type: .CARD_NUMBER,
                customErrorMessage: cardNumberTranslation.errorText
            )

            // Get translations for CARDHOLDER_NAME
            let cardholderNameTranslation = getTranslation(for: .CARDHOLDER_NAME)
            let collectNameInput = CollectElementInput(
                table: tableName,
                column: "cardholder_name",
                inputStyles: config.fieldConfig(for: .CARDHOLDER_NAME)?.style?.skyflowStyles ?? styles,
                labelStyles: config.style.labelStyles,
                errorTextStyles: config.style.errorStyles,
                label: cardholderNameTranslation.label ?? config.fieldConfig(for: .CARDHOLDER_NAME)?.title ?? "Card Holder Name",
                placeholder: cardholderNameTranslation.placeholder ?? config.fieldConfig(for: .CARDHOLDER_NAME)?.placeholder ?? "",
                type: .CARDHOLDER_NAME,
                customErrorMessage: cardholderNameTranslation.errorText
            )
            
            // Get translations for CVV
            let cvvTranslation = getTranslation(for: .CVV)
            let collectCVVInput = CollectElementInput(
                table: tableName,
                column: "security_code",
                inputStyles: config.fieldConfig(for: .CVV)?.style?.skyflowStyles ?? styles,
                labelStyles: config.style.labelStyles,
                errorTextStyles: config.style.errorStyles,
                label: cvvTranslation.label ?? config.fieldConfig(for: .CVV)?.title ?? "CVV",
                placeholder: cvvTranslation.placeholder ?? config.fieldConfig(for: .CVV)?.placeholder ?? "***",
                type: .CVV,
                customErrorMessage: cvvTranslation.errorText
            )
            
            // Get translations for EXPIRATION_MONTH
            let expiryMonthTranslation = getTranslation(for: .EXPIRATION_MONTH)
            let collectExpMonthInput = CollectElementInput(
                table: tableName,
                column: "expiry_month",
                inputStyles: config.fieldConfig(for: .EXPIRATION_MONTH)?.style?.skyflowStyles ?? styles,
                labelStyles: config.style.labelStyles,
                errorTextStyles: config.style.errorStyles,
                label: expiryMonthTranslation.label ?? config.fieldConfig(for: .EXPIRATION_MONTH)?.title ?? "Expiration Month",
                placeholder: expiryMonthTranslation.placeholder ?? config.fieldConfig(for: .EXPIRATION_MONTH)?.placeholder ?? "MM",
                type: .EXPIRATION_MONTH,
                customErrorMessage: expiryMonthTranslation.errorText
            )
            
            // Get translations for EXPIRATION_YEAR
            let expiryYearTranslation = getTranslation(for: .EXPIRATION_YEAR)
            let collectExpYearInput = CollectElementInput(
                table: tableName,
                column: "expiry_year",
                inputStyles: config.fieldConfig(for: .EXPIRATION_YEAR)?.style?.skyflowStyles ?? styles,
                labelStyles: config.style.labelStyles,
                errorTextStyles: config.style.errorStyles,
                label: expiryYearTranslation.label ?? config.fieldConfig(for: .EXPIRATION_YEAR)?.title ?? "Expiration Year",
                placeholder: expiryYearTranslation.placeholder ?? config.fieldConfig(for: .EXPIRATION_YEAR)?.placeholder ?? "YYYY",
                type: .EXPIRATION_YEAR,
                customErrorMessage: expiryYearTranslation.errorText
            )
            
            // Get translations for EXPIRATION_DATE
            let expiryDateTranslation = getTranslation(for: .EXPIRATION_DATE)
            let collectExpDateInput = CollectElementInput(
                table: tableName,
                column: "expiry_date",
                inputStyles: config.fieldConfig(for: .EXPIRATION_DATE)?.style?.skyflowStyles ?? styles,
                labelStyles: config.style.labelStyles,
                errorTextStyles: config.style.errorStyles,
                label: expiryDateTranslation.label ?? config.fieldConfig(for: .EXPIRATION_DATE)?.title ?? "Expiration Date",
                placeholder: expiryDateTranslation.placeholder ?? config.fieldConfig(for: .EXPIRATION_DATE)?.placeholder ?? "MM/YY",
                type: .EXPIRATION_DATE,
                customErrorMessage: expiryDateTranslation.errorText
            )
                
            let requiredOption = CollectElementOptions(required: true)
            _ = container.create(input: collectCardNumberInput, options: requiredOption)

            _ = container.create(input: collectCVVInput, options: requiredOption)
            if config.showNameField {
                _ = container.create(input: collectNameInput, options: requiredOption)
            }
            _ = container.create(input: collectExpMonthInput, options: requiredOption)
            _ = container.create(input: collectExpYearInput, options: requiredOption)

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
