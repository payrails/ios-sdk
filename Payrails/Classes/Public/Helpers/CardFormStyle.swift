import PayrailsVault

public typealias CardStyle = Style
public typealias CardFieldType = ElementType

public struct CardFormConfig {
    public let style: CardFormStyle
    public let showNameField: Bool
    public let fieldConfigs: [CardFieldConfig]

    public init(
        style: CardFormStyle = .defaultStyle,
        showNameField: Bool = true,
        fieldConfigs: [CardFieldConfig] = []
    ) {
        self.style = style
        self.showNameField = showNameField
        self.fieldConfigs = fieldConfigs
    }

    public static var defaultConfig: CardFormConfig {
        .init(
            style: .defaultStyle,
            showNameField: true,
            fieldConfigs: []
        )
    }

    static var dropInConfig: CardFormConfig {
        .init(
            style: .init(
                baseStyle: .init(
                    borderColor: .black.withAlphaComponent(0.81),
                    cornerRadius: 6,
                    padding: UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8),
                    borderWidth: 1,
                    font: .systemFont(ofSize: 12),
                    textAlignment: .left,
                    textColor: .black.withAlphaComponent(0.81)
                ),
                focusStyle: .init(borderColor: .black.withAlphaComponent(0.81)),
                labelStyle: .init(
                    font: .systemFont(ofSize: 12),
                    textColor: .black.withAlphaComponent(0.81)
                ),
                completedStyle: .init(borderColor: .black.withAlphaComponent(0.81)),
                invalidStyle: .init(borderColor: .red.withAlphaComponent(0.81)),
                errorTextStyle: .init(
                    font: .systemFont(ofSize: 10),
                    textColor: .red
                )
            ),
            showNameField: false
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
            labelStyle: .init(textColor: .black),
            completedStyle: .init(borderColor: .green),
            invalidStyle: .init(borderColor: .red),
            errorTextStyle: .init(textColor: UIColor.red)
        )
    }

    public let baseStyle: CardStyle?
    public let focusStyle: CardStyle?
    public let completedStyle: CardStyle?
    public let labelStyle: CardStyle?
    public let invalidStyle: CardStyle?
    public let errorTextStyle: CardStyle?

    public init(
        baseStyle: CardStyle?,
        focusStyle: CardStyle? = nil,
        labelStyle: CardStyle?,
        completedStyle: CardStyle? = nil,
        invalidStyle: CardStyle? = nil,
        errorTextStyle: CardStyle? = nil
    ) {
        self.baseStyle = baseStyle
        self.focusStyle = focusStyle
        self.completedStyle = completedStyle
        self.labelStyle = labelStyle
        self.invalidStyle = invalidStyle
        self.errorTextStyle = errorTextStyle
    }

    var skyflowStyles: Styles {
        Styles(
            base: baseStyle,
            complete: completedStyle,
            focus: focusStyle,
            invalid: invalidStyle
        )
    }

    var labelStyles: Styles {
        Styles(
            base: labelStyle,
            complete: labelStyle,
            focus: labelStyle,
            invalid: labelStyle
        )
    }

    var errorStyles: Styles {
        Styles(
            base: errorTextStyle,
            complete: errorTextStyle,
            focus: errorTextStyle,
            invalid: errorTextStyle
        )
    }
}

extension CardFormConfig {
    func fieldConfig(for type: CardFieldType) -> CardFieldConfig? {
        fieldConfigs.first(where: { $0.type == type })
    }
}
