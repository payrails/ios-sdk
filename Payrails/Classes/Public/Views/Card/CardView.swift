import UIKit
import PayrailsCSE

public final class CardCollectContainer: CardContainer {
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

public class CardCollectView: UIStackView {
    private let config: CardFormConfig
    private let skyflow: Client
    private var container: Container<ComposableContainer>?
    private let tableName: String
    public var cardContainer: CardCollectContainer?
    private var payrailsCSE: PayrailsCSE?
    
    public init(
        skyflow: Client,
        config: CardFormConfig,
        tableName: String,
        cseConfig: String
    ) {
        self.skyflow = skyflow
        self.config = config
        self.tableName = tableName
        super.init(frame: .zero)
        
        // Initialize PayrailsCSE
        do {
            self.payrailsCSE = try PayrailsCSE(data: cseConfig, version: "1.0.0")
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
                layout: config.showNameField ? [2, 1, 2] : [1, 1, 2],
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
            
            // Add test button
            let button = UIButton(type: .system)
            button.setTitle("Test Button", for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = .black
            button.layer.cornerRadius = 8
            button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
            self.addArrangedSubview(button)
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
    
    @objc private func buttonTapped() {
        guard let container = self.container else { return }
        
        // Create a callback to handle the collected data
        let callback = CardCollectCallback()
        callback.onSuccess = { [weak self] responseBody in
            guard let self = self else { return }
            
            // Parse the response to get card details
            if let records = responseBody as? [[String: Any]],
               let firstRecord = records.first,
               let cardData = firstRecord["records"] as? [[String: Any]],
               let cardNumber = cardData.first(where: { ($0["column"] as? String) == "card_number" })?["value"] as? String,
               let expiryMonth = cardData.first(where: { ($0["column"] as? String) == "expiry_month" })?["value"] as? String,
               let expiryYear = cardData.first(where: { ($0["column"] as? String) == "expiry_year" })?["value"] as? String,
               let securityCode = cardData.first(where: { ($0["column"] as? String) == "security_code" })?["value"] as? String {
                
                // Create card object
                // Use Card from PayrailsCSE import
                let payrailsCard = Card(
                    holderReference: "nil",
                    cardNumber: cardNumber,
                    expiryMonth: expiryMonth,
                    expiryYear: expiryYear,
                    holderName: "nil",
                    securityCode: securityCode
                )
                
                do {
                    // Encrypt card data
                    if let payrailsCSE = self.payrailsCSE {
                        let encryptedData = try payrailsCSE.encryptCardData(card: payrailsCard)
                        print("Successfully encrypted card data:", encryptedData)
                    }
                } catch {
                    print("Failed to encrypt card data:", error)
                }
            }
        }
        
        callback.onFailure = { error in
            print("Failed to collect card data:", error)
        }
        
        // Collect the data
        cardContainer?.collect(with: callback)
    }
}
