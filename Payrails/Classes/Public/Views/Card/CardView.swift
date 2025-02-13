import UIKit

final class CardCollectContainer: CardContainer {
    let container: Container<ComposableContainer>

    init(container: Container<ComposableContainer>) {
        self.container = container
    }

    func collect(with callback: Callback) {
        container.collect(
            callback: callback
        )
    }
}


final class CardCollectView: UIStackView {
    private let config: CardFormConfig
    private let skyflow: Client
    private var container: Container<ComposableContainer>?
    private let tableName: String
    var cardContainer: CardCollectContainer?

    init(
        skyflow: Client,
        config: CardFormConfig,
        tableName: String
    ) {
        self.skyflow = skyflow
        self.config = config
        self.tableName = tableName
        super.init(frame: .zero)
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
                layout: config.showNameField ? [2, 1, 2] : [2, 2],
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
}
