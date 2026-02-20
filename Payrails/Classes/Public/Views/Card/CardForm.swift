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
        
        // Save instrument properties
        public var saveInstrument: Bool = false {
            didSet {
                saveInstrumentToggle.isOn = saveInstrument
            }
        }
        internal let saveInstrumentToggle = UISwitch()
        internal let saveInstrumentLabel = UILabel()
        
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

            let stylesConfig = config.styles ?? CardFormStylesConfig.defaultConfig
            let wrapperStyle = stylesConfig.wrapperStyle ?? CardWrapperStyle.defaultStyle

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
                self.clipsToBounds = true
            } else {
                self.clipsToBounds = false
            }
            
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
            let stylesConfig = config.styles ?? CardFormStylesConfig.defaultConfig
            let defaultLabelStyle = CardStyle(textColor: .darkGray)
            let defaultErrorStyle = CardStyle(textColor: .red)
            let containerErrorStyle = stylesConfig.errorTextStyle ?? defaultErrorStyle
            let iconAlignment = config.cardIconAlignment
            let layoutRows = sanitizedLayoutRows(from: resolvedLayoutRows())

            guard !layoutRows.isEmpty else {
                print("Card form layout does not contain supported fields")
                return
            }

            guard let container = self.containerClient.container(
                type: ContainerType.COMPOSABLE,
                options: ContainerOptions(
                    layout: layoutRows.map(\.count),
                    errorTextStyles: Styles(base: containerErrorStyle)
                )
            ) else {
                print("Failed to create Composable Container")
                return
            }

            self.container = container
            self.cardContainer = CardCollectContainer(container: container)

            let requiredOption = CollectElementOptions(
                required: true,
                enableCardIcon: config.showCardIcon,
                enableCopy: true,
                showRequiredAsterisk: config.showRequiredAsterisk
            )

            for fieldType in layoutRows.flatMap({ $0 }) {
                guard let input = makeCollectInput(
                    for: fieldType,
                    stylesConfig: stylesConfig,
                    defaultLabelStyle: defaultLabelStyle,
                    containerErrorStyle: containerErrorStyle,
                    iconAlignment: iconAlignment
                ) else {
                    continue
                }
                _ = container.create(input: input, options: requiredOption)
            }

            container.setupDynamicCVVLengthHandling()

            self.axis = .vertical
            self.spacing = stylesConfig.fieldSpacing ?? 10

            do {
                let composableView = try container.getComposableView()
                self.addArrangedSubview(composableView)
            } catch {
                print("Error getting composable view: \(error)")
            }

            if config.showSaveInstrument {
                setupSaveInstrumentToggle()
            }
        }

        private func resolvedLayoutRows() -> [[CardFieldType]] {
            if let layout = config.layout {
                return layout.resolvedRows(showNameField: config.showNameField)
            }
            return CardLayoutConfig.defaultRows(showNameField: config.showNameField)
        }

        private func sanitizedLayoutRows(from rows: [[CardFieldType]]) -> [[CardFieldType]] {
            let supportedRows = rows
                .map { row in row.filter { isSupportedField($0) } }
                .filter { !$0.isEmpty }

            if supportedRows.isEmpty {
                return CardLayoutConfig.defaultRows(showNameField: config.showNameField)
            }
            return supportedRows
        }

        private func isSupportedField(_ fieldType: CardFieldType) -> Bool {
            switch fieldType {
            case .CARD_NUMBER, .CARDHOLDER_NAME, .CVV, .EXPIRATION_MONTH, .EXPIRATION_YEAR, .EXPIRATION_DATE:
                return true
            default:
                return false
            }
        }

        private func makeCollectInput(
            for fieldType: CardFieldType,
            stylesConfig: CardFormStylesConfig,
            defaultLabelStyle: CardStyle,
            containerErrorStyle: CardStyle,
            iconAlignment: CardIconAlignment
        ) -> CollectElementInput? {
            guard let column = columnName(for: fieldType) else {
                return nil
            }

            let translation = getTranslation(for: fieldType)
            let inputStyle = stylesConfig.effectiveInputStyles(for: fieldType)
            let labelStyle = labelStyle(for: fieldType, stylesConfig: stylesConfig, defaultLabelStyle: defaultLabelStyle)
            let iconStyle: Styles = fieldType == .CARD_NUMBER
                ? Styles(base: CardStyle(cardIconAlignment: iconAlignment))
                : Styles()

            return CollectElementInput(
                table: tableName,
                column: column,
                inputStyles: inputStyle.skyflowStyles,
                labelStyles: Styles(base: labelStyle),
                errorTextStyles: Styles(base: containerErrorStyle),
                iconStyles: iconStyle,
                label: translation.label ?? "",
                placeholder: translation.placeholder ?? defaultPlaceholder(for: fieldType),
                type: fieldType,
                customErrorMessage: translation.errorText
            )
        }

        private func getTranslation(for fieldType: CardFieldType) -> (placeholder: String?, label: String?, errorText: String?) {
            let placeholder = config.translations?.placeholders[fieldType]
            let label = config.translations?.labels[fieldType]
            let errorText = config.translations?.error[fieldType]
            return (placeholder, label, errorText)
        }

        private func labelStyle(
            for fieldType: CardFieldType,
            stylesConfig: CardFormStylesConfig,
            defaultLabelStyle: CardStyle
        ) -> CardStyle {
            switch fieldType {
            case .EXPIRATION_MONTH, .EXPIRATION_YEAR:
                return stylesConfig.labelStyles?[fieldType]
                    ?? stylesConfig.labelStyles?[.EXPIRATION_DATE]
                    ?? defaultLabelStyle
            default:
                return stylesConfig.labelStyles?[fieldType] ?? defaultLabelStyle
            }
        }

        private func columnName(for fieldType: CardFieldType) -> String? {
            switch fieldType {
            case .CARD_NUMBER:
                return "card_number"
            case .CARDHOLDER_NAME:
                return "cardholder_name"
            case .CVV:
                return "security_code"
            case .EXPIRATION_MONTH:
                return "expiry_month"
            case .EXPIRATION_YEAR:
                return "expiry_year"
            case .EXPIRATION_DATE:
                return "expiry_date"
            default:
                return nil
            }
        }

        private func defaultPlaceholder(for fieldType: CardFieldType) -> String {
            switch fieldType {
            case .CARD_NUMBER:
                return "•••• •••• •••• ••••"
            case .CARDHOLDER_NAME:
                return "Full Name"
            case .CVV:
                return "•••"
            case .EXPIRATION_MONTH:
                return "MM"
            case .EXPIRATION_YEAR:
                return "YYYY"
            case .EXPIRATION_DATE:
                return "MM/YY"
            default:
                return ""
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
        
        private func setupSaveInstrumentToggle() {
            // Configure label
            let labelText = config.translations?.labels.saveInstrument ?? "Save card"
            saveInstrumentLabel.text = labelText
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
            self.addArrangedSubview(toggleContainer)
            
            // Link toggle to property
            saveInstrumentToggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        }
        
        @objc private func toggleChanged() {
            self.saveInstrument = saveInstrumentToggle.isOn
        }
        
        public func collectFields() {
            guard let container = self.container else { return }
            
            let callback = CardCollectCallback()
            
            callback.onSuccess = { [weak self] responseBody in
                guard let self = self else { return }

                guard
                    let response = responseBody as? [String: Any],
                    let records = response["records"] as? [[String: Any]],
                    let firstRecord = records.first,
                    let fields = firstRecord["fields"] as? [String: Any]
                else {
                    self.notifyCollectionFailure(PayrailsError.invalidDataFormat)
                    return
                }

                guard
                    let cardNumber = fields["card_number"] as? String,
                    let securityCode = fields["security_code"] as? String
                else {
                    self.notifyCollectionFailure(PayrailsError.invalidCardData)
                    return
                }

                guard let expiry = self.resolveExpiry(from: fields) else {
                    self.notifyCollectionFailure(PayrailsError.invalidCardData)
                    return
                }

                let payrailsCard = Card(
                    holderReference: self.holderReference,
                    cardNumber: cardNumber,
                    expiryMonth: expiry.month,
                    expiryYear: expiry.year,
                    holderName: fields["cardholder_name"] as? String,
                    securityCode: securityCode
                )

                guard let payrailsCSE = self.payrailsCSE else {
                    self.notifyCollectionFailure(PayrailsError.missingData("CSE instance"))
                    return
                }

                do {
                    let encryptedCardData = try payrailsCSE.encryptCardData(card: payrailsCard)
                    DispatchQueue.main.async {
                        self.delegate?.cardForm(self, didCollectCardData: encryptedCardData)
                    }
                } catch {
                    print("Failed to encrypt card data:", error)
                    self.notifyCollectionFailure(error)
                }
            }
            
            callback.onFailure = { [weak self] error in
                print("Failed to collect card data:", error)
                self?.notifyCollectionFailure(PayrailsError.invalidCardData)
            }
            
            cardContainer?.collect(with: callback)
        }

        private func notifyCollectionFailure(_ error: Error) {
            DispatchQueue.main.async {
                self.delegate?.cardForm(self, didFailWithError: error)
            }
        }

        private func resolveExpiry(from fields: [String: Any]) -> (month: String, year: String)? {
            if
                let expiryMonth = fields["expiry_month"] as? String,
                let expiryYear = fields["expiry_year"] as? String
            {
                return (month: expiryMonth, year: expiryYear)
            }

            guard let combinedExpiry = fields["expiry_date"] as? String else {
                return nil
            }

            return parseCombinedExpiry(combinedExpiry)
        }

        private func parseCombinedExpiry(_ value: String) -> (month: String, year: String)? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let parts = trimmed.split(separator: "/").map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if parts.count == 2 {
                if isValidMonth(parts[0]) {
                    return (month: parts[0], year: parts[1])
                }
                if isValidMonth(parts[1]) {
                    return (month: parts[1], year: parts[0])
                }
            }

            let digits = trimmed.filter { $0.isWholeNumber }
            if digits.count == 4 {
                let month = String(digits.prefix(2))
                let year = String(digits.suffix(2))
                return isValidMonth(month) ? (month: month, year: year) : nil
            }

            if digits.count == 6 {
                let firstMonth = String(digits.prefix(2))
                if isValidMonth(firstMonth) {
                    return (month: firstMonth, year: String(digits.suffix(4)))
                }

                let trailingMonth = String(digits.suffix(2))
                if isValidMonth(trailingMonth) {
                    return (month: trailingMonth, year: String(digits.prefix(4)))
                }
            }

            return nil
        }

        private func isValidMonth(_ month: String) -> Bool {
            guard month.count == 2, let monthInt = Int(month) else {
                return false
            }
            return (1...12).contains(monthInt)
        }
    }
}
