import UIKit
import PayrailsCSE

public protocol CardFormDelegate: AnyObject {
    func cardCollectView(_ view: CardForm, didCollectCardData data: TokenizeResponse)
    func cardCollectView(_ view: CardForm, didFailWithError error: Error)
}

public final class CardCollectContainer: CardContainer{
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

public class CardForm: UIStackView {
    public weak var delegate: CardFormDelegate?

    private let config: CardFormConfig
    private let skyflow: Client
    private var container: Container<ComposableContainer>?
    private let tableName: String
    private let holderReference: String
    public var cardContainer: CardCollectContainer?
    private var payrailsCSE: PayrailsCSE?
    
    
    public init(
        skyflow: Client,
        config: CardFormConfig,
        tableName: String,
        cseConfig: (data: String, version: String),
        holderReference: String
    ) {
        self.skyflow = skyflow
        self.config = config
        self.tableName = tableName
        self.holderReference = holderReference
        
        super.init(frame: .zero)
        
        // Add border to the view
        self.layer.borderWidth = 1.0
        self.layer.borderColor = UIColor.gray.cgColor
        self.layer.cornerRadius = 8.0
        self.clipsToBounds = true
        
        // Add padding
        self.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        self.isLayoutMarginsRelativeArrangement = true
        
        // Initialize PayrailsCSE
        do {
            self.payrailsCSE = try PayrailsCSE(data: cseConfig.data, version: cseConfig.version)
        } catch {
            print("Failed to initialize PayrailsCSE:", error)
        }
        
        setupViews()
    }

    required init(coder: NSCoder) {
        fatalError(
            "Not implemented: please use init(skyflow: Skyflow.Client, config: Skyflow.Configuration)"
        )
    }

    private func setupViews() {
        guard let container = skyflow.container(
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

        let collectCardNumberInput = CollectElementInput(
            table: tableName,
            column: "card_number",
            inputStyles: config.fieldConfig(for: .CARD_NUMBER)?.style?.skyflowStyles ?? styles,
            labelStyles: config.style.labelStyles,
            errorTextStyles: config.style.errorStyles,
            label: config.fieldConfig(for: .CARD_NUMBER)?.title ?? "Card Number",
            placeholder: config.fieldConfig(for: .CARD_NUMBER)?.placeholder ?? "Card Number",
            type: .CARD_NUMBER
        )

        let collectNameInput = CollectElementInput(
            table: tableName,
            column: "cardholder_name",
            inputStyles: config.fieldConfig(for: .CARDHOLDER_NAME)?.style?.skyflowStyles ?? styles,
            labelStyles: config.style.labelStyles,
            errorTextStyles: config.style.errorStyles,
            label: config.fieldConfig(for: .CARDHOLDER_NAME)?.title ?? "Card Holder Name",
            placeholder: config.fieldConfig(for: .CARDHOLDER_NAME)?.placeholder ?? "",
            type: .CARDHOLDER_NAME
        )
        let collectCVVInput = CollectElementInput(
            table: tableName,
            column: "security_code",
            inputStyles: config.fieldConfig(for: .CVV)?.style?.skyflowStyles ?? styles,
            labelStyles: config.style.labelStyles,
            errorTextStyles: config.style.errorStyles,
            label: config.fieldConfig(for: .CVV)?.title ??  "CVV",
            placeholder: config.fieldConfig(for: .CVV)?.placeholder ?? "***",
            type: .CVV
        )
        let collectExpMonthInput = CollectElementInput(
            table: tableName,
            column: "expiry_month",
            inputStyles: config.fieldConfig(for: .EXPIRATION_MONTH)?.style?.skyflowStyles ?? styles,
            labelStyles: config.style.labelStyles,
            errorTextStyles: config.style.errorStyles,
            label: config.fieldConfig(for: .EXPIRATION_MONTH)?.title ??  "Expiration Month",
            placeholder: config.fieldConfig(for: .EXPIRATION_MONTH)?.placeholder ?? "MM",
            type: .EXPIRATION_MONTH
        )
        let collectExpYearInput = CollectElementInput(
            table: tableName,
            column: "expiry_year",
            inputStyles: config.fieldConfig(for: .EXPIRATION_YEAR)?.style?.skyflowStyles ?? styles,
            labelStyles: config.style.labelStyles,
            errorTextStyles: config.style.errorStyles,
            label: config.fieldConfig(for: .EXPIRATION_YEAR)?.title ??  "Expiration Year",
            placeholder: config.fieldConfig(for: .EXPIRATION_YEAR)?.placeholder ?? "YYYY",
            type: .EXPIRATION_YEAR
        )
        let collectExpDateInput = CollectElementInput(
            table: tableName,
            column: "expiry_date",
            inputStyles: config.fieldConfig(for: .EXPIRATION_DATE)?.style?.skyflowStyles ?? styles,
            labelStyles: config.style.labelStyles,
            errorTextStyles: config.style.errorStyles,
            label: config.fieldConfig(for: .EXPIRATION_DATE)?.title ??  "Expiration Date",
            placeholder: config.fieldConfig(for: .CVV)?.placeholder ?? "***",
            type: .EXPIRATION_DATE
        )
            
        let requiredOption = CollectElementOptions(required: true)
        _ = container.create(input: collectCardNumberInput, options: requiredOption)
//        _ = container.create(input: collectExpDateInput, options: requiredOption)
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
    
    public func collectFields() -> String? {
        guard let container = self.container else { return nil }
        
        // Create a callback to handle the collected data
        let callback = CardCollectCallback()
        var encryptedCardData: String?
        
        callback.onSuccess = { [weak self] responseBody in
            guard let self = self else { return }

            print("Successfully collected card data:", responseBody)
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
                        print("Successfully encrypted card data is here:", encryptedCardData ?? "")
                    }
                } catch {
                    print("Failed to encrypt card data:", error)
                }
            }
        }
        
        callback.onFailure = { error in
            print("Failed to collect card data:", error)
        }
        
        // Perform collection
        cardContainer?.collect(with: callback)
        
        return encryptedCardData
    }
    
    public func tokenizeFields() {
        guard let container = self.container else { return }
        
        // Create a callback to handle the collected data
        let callback = CardCollectCallback()
        callback.onSuccess = { [weak self] responseBody in
            guard let self = self else { return }

            print("Successfully collected card data:", responseBody)
            if let response = responseBody as? [String: Any],
               let records = response["records"] as? [[String: Any]],
               let firstRecord = records.first,
               let fields = firstRecord["fields"] as? [String: Any],
               let cardNumber = fields["card_number"] as? String,
               let expiryMonth = fields["expiry_month"] as? String,
               let expiryYear = fields["expiry_year"] as? String,
               let securityCode = fields["security_code"] as? String {
                
                do {
                    if let payrailsCSE = self.payrailsCSE {
                        // Call tokenize only
                        let tokenizedResponse = try payrailsCSE.tokenize(
                            cardNumber: cardNumber,
                            expiryMonth: expiryMonth,
                            expiryYear: expiryYear,
                            holderName: "sdssdsds",
                            securityCode: securityCode,
                            completion: { [weak self] (result: Result<TokenizeResponse, Error>) in
                                guard let self = self else { return }

                                switch result {
                                case .success(let response):
                                    // debugPrint("tokenization request successful totally")
                                    // debugPrint(response)
                                    DispatchQueue.main.async {
                                        self.delegate?.cardCollectView(self, didCollectCardData: response)
                                    }
                                case .failure(let error):
                                    debugPrint("tokenization request failed")
                                    debugPrint("Error: \(error)")
                                    DispatchQueue.main.async {
                                        self.delegate?.cardCollectView(self, didFailWithError: error)
                                    }
                                }
                            }
                        )
                    }
                } catch {
                    print("Failed to tokenize card data:", error)
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
