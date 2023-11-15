import Skyflow

public struct CardField  {
    public let type: CardFieldType
    public let textField: TextField

    init(type: CardFieldType, textField: TextField) {
        self.type = type
        self.textField = textField
    }
}

final class CardElementsContainer: CardContainer {
    let container: Skyflow.Container<Skyflow.CollectContainer>

    init(container: Skyflow.Container<Skyflow.CollectContainer>) {
        self.container = container
    }

    func collect(with callback: Skyflow.Callback) {
        container.collect(
            callback: callback,
            options: Skyflow.CollectOptions(tokens: true)
        )
    }
}

final class CardFormElementsGenerator {

    private let config: CardFormConfig
    private let skyflow: Skyflow.Client
    private let tableName: String
    private let container: Skyflow.Container<Skyflow.CollectContainer>
    let cardElemenetsContainer: CardElementsContainer

    init?(
        skyflow: Skyflow.Client,
        config: CardFormConfig,
        tableName: String
    ) {
        self.skyflow = skyflow
        self.config = config
        self.tableName = tableName

        guard let container = skyflow.container(
            type: Skyflow.ContainerType.COLLECT,
            options: nil
        ) else {
            return nil
        }
        self.container = container
        self.cardElemenetsContainer = .init(container: container)
    }

    func buildCardFields() -> [CardField] {
        let styles = config.style.skyflowStyles

        let collectCardNumberInput = Skyflow.CollectElementInput(
            table: tableName,
            column: "card_number",
            inputStyles: config.fieldConfig(for: .CARD_NUMBER)?.style?.skyflowStyles ?? styles,
            labelStyles: config.style.labelStyles,
            errorTextStyles: config.style.errorStyles,
            label: config.fieldConfig(for: .CARD_NUMBER)?.title ?? "Card Number",
            placeholder: config.fieldConfig(for: .CARD_NUMBER)?.placeholder ?? "4111-1111-1111-1111",
            type: .CARD_NUMBER
        )

        let collectNameInput = Skyflow.CollectElementInput(
            table: tableName,
            column: "cardholder_name",
            inputStyles: config.fieldConfig(for: .CARDHOLDER_NAME)?.style?.skyflowStyles ?? styles,
            labelStyles: config.style.labelStyles,
            errorTextStyles: config.style.errorStyles,
            label: config.fieldConfig(for: .CARDHOLDER_NAME)?.title ?? "Card Holder Name",
            placeholder: config.fieldConfig(for: .CARDHOLDER_NAME)?.placeholder ?? "",
            type: .CARDHOLDER_NAME
        )
        let collectCVVInput = Skyflow.CollectElementInput(
            table: tableName,
            column: "security_code",
            inputStyles: config.fieldConfig(for: .CVV)?.style?.skyflowStyles ?? styles,
            labelStyles: config.style.labelStyles,
            errorTextStyles: config.style.errorStyles,
            label: config.fieldConfig(for: .CVV)?.title ??  "CVV",
            placeholder: config.fieldConfig(for: .CVV)?.placeholder ?? "***",
            type: .CVV
        )
        let collectExpMonthInput = Skyflow.CollectElementInput(
            table: tableName,
            column: "expiry_month",
            inputStyles: config.fieldConfig(for: .EXPIRATION_MONTH)?.style?.skyflowStyles ?? styles,
            labelStyles: config.style.labelStyles,
            errorTextStyles: config.style.errorStyles,
            label: config.fieldConfig(for: .EXPIRATION_MONTH)?.title ??  "Expiration Month",
            placeholder: config.fieldConfig(for: .EXPIRATION_MONTH)?.placeholder ?? "MM",
            type: .EXPIRATION_MONTH
        )
        let collectExpYearInput = Skyflow.CollectElementInput(
            table: tableName,
            column: "expiry_year",
            inputStyles: config.fieldConfig(for: .EXPIRATION_YEAR)?.style?.skyflowStyles ?? styles,
            labelStyles: config.style.labelStyles,
            errorTextStyles: config.style.errorStyles,
            label: config.fieldConfig(for: .EXPIRATION_YEAR)?.title ??  "Expiration Year",
            placeholder: config.fieldConfig(for: .EXPIRATION_YEAR)?.placeholder ?? "YYYY",
            type: .EXPIRATION_YEAR
        )

        var results: [CardField] = []

        let collectCardNumber = container.create(input: collectCardNumberInput, options: Skyflow.CollectElementOptions(required: true, format: "XXXX-XXXX-XXXX-XXXX"))
        results.append(.init(type: .CARD_NUMBER, textField: collectCardNumber))
        
        if config.showNameField {
            let collectName = container.create(input: collectNameInput, options: Skyflow.CollectElementOptions(required: true))
            results.append(.init(type: .CARDHOLDER_NAME, textField: collectName))
        }
        
        let collectCVV = container.create(input: collectCVVInput, options: Skyflow.CollectElementOptions(required: true))
        results.append(.init(type: .CVV, textField: collectCVV))
        
        let collectExpMonth = container.create(input: collectExpMonthInput, options: Skyflow.CollectElementOptions(required: true))
        results.append(.init(type: .EXPIRATION_MONTH, textField: collectExpMonth))

        let collectExpYear = container.create(input: collectExpYearInput, options: Skyflow.CollectElementOptions(required: true))
        results.append(.init(type: .EXPIRATION_YEAR, textField: collectExpYear))

        return results
    }
}
