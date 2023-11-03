import Skyflow

public typealias CardStyle = Skyflow.Style
public typealias CardFieldType = Skyflow.ElementType

public struct CardFormConfig {
    public let payButton: UIButton
    public let style: CardFormStyle
    public let showNameField: Bool
    public let fieldConfigs: [CardFieldConfig]

    public init(
        style: CardFormStyle = .defaultStyle,
        showNameField: Bool = true,
        fieldConfigs: [CardFieldConfig] = [],
        payButton: UIButton = {
            let cardButton = CardSubmitButton()
            let heightConstraint = cardButton.heightAnchor.constraint(equalToConstant: 46)
            heightConstraint.priority = .init(500)
            NSLayoutConstraint.activate(
                [
                    heightConstraint
                ]
            )
            return cardButton
        }()
    ) {
        self.style = style
        self.showNameField = showNameField
        self.fieldConfigs = fieldConfigs
        self.payButton = payButton
    }

    public static var defaultConfig: CardFormConfig {
        .init(
            style: .defaultStyle,
            showNameField: true,
            fieldConfigs: []
        )
    }
}

public struct CardFieldConfig {
    public let type: CardFieldType
    public let placeholder: String?
    public let title: String?
    public let style: CardFormStyle?

    public init(
        type: CardFieldType,
        placeholder: String? = nil,
        title: String? = nil,
        style: CardFormStyle? = nil
    ) {
        self.type = type
        self.placeholder = placeholder
        self.title = title
        self.style = style
    }
}

public struct CardFormStyle {
    public static var defaultStyle: CardFormStyle {
        .init(
            baseStyle: .init(
                cornerRadius: 2,
                padding: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10),
                borderWidth: 1,
                textAlignment: .left,
                textColor: .blue
            ),
            focusStyle: .init(borderColor: .blue),
            completedStyle: .init(borderColor: .green),
            invalidStyle: .init(borderColor: .red),
            errorTextStyle: .init(textColor: UIColor.red)
        )
    }

    public let baseStyle: CardStyle?
    public let focusStyle: CardStyle?
    public let completedStyle: CardStyle?
    public let invalidStyle: CardStyle?
    public let errorTextStyle: CardStyle?

    public init(
        baseStyle: CardStyle?,
        focusStyle: CardStyle? = nil,
        completedStyle: CardStyle? = nil,
        invalidStyle: CardStyle? = nil,
        errorTextStyle: CardStyle? = nil
    ) {
        self.baseStyle = baseStyle
        self.focusStyle = focusStyle
        self.completedStyle = completedStyle
        self.invalidStyle = invalidStyle
        self.errorTextStyle = errorTextStyle
    }

    var skyflowStyles: Skyflow.Styles {
        Skyflow.Styles(
            base: baseStyle,
            complete: completedStyle,
            focus: focusStyle,
            invalid: invalidStyle
        )
    }
}
