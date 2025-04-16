public typealias CardStyle = Style
public typealias CardFieldType = ElementType

public struct CardFormConfig {
    public let showNameField: Bool
    public let translations: CardTranslations?
    public let styles: [CardFieldType: CardFormStyle]?

    public init(
        showNameField: Bool = false,
        styles: [CardFieldType: CardFormStyle]? = nil,
        translations: CardTranslations? = nil
    ) {
        self.showNameField = showNameField
        self.translations = translations
        self.styles = styles
    }

    public static var defaultConfig: CardFormConfig {
        var defaultStyles: [CardFieldType: CardFormStyle] = [:]

        defaultStyles[CardFieldType.CARD_NUMBER] = CardFormStyle.defaultStyle
        defaultStyles[CardFieldType.CVV] = CardFormStyle.defaultStyle
        defaultStyles[CardFieldType.EXPIRATION_DATE] = CardFormStyle.defaultStyle
        defaultStyles[CardFieldType.EXPIRATION_MONTH] = CardFormStyle.defaultStyle
        defaultStyles[CardFieldType.EXPIRATION_YEAR] = CardFormStyle.defaultStyle
        defaultStyles[CardFieldType.CARDHOLDER_NAME] = CardFormStyle.defaultStyle
        
        return .init(
            showNameField: true,
            styles: defaultStyles
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
    
    
    public static var empty: CardFormStyle {
        .init(baseStyle: nil, labelStyle: nil)
    }
    
    public func merged(over base: CardFormStyle?) -> CardFormStyle {
        let baseFormStyle = base ?? CardFormStyle.empty
        return CardFormStyle(
            baseStyle: self.baseStyle?.merged(over: baseFormStyle.baseStyle) ?? baseFormStyle.baseStyle,
            focusStyle: self.focusStyle?.merged(over: baseFormStyle.focusStyle) ?? baseFormStyle.focusStyle,
            labelStyle: self.labelStyle?.merged(over: baseFormStyle.labelStyle) ?? baseFormStyle.labelStyle,
            completedStyle: self.completedStyle?.merged(over: baseFormStyle.completedStyle) ?? baseFormStyle.completedStyle,
            invalidStyle: self.invalidStyle?.merged(over: baseFormStyle.invalidStyle) ?? baseFormStyle.invalidStyle,
            errorTextStyle: self.errorTextStyle?.merged(over: baseFormStyle.errorTextStyle) ?? baseFormStyle.errorTextStyle
        )
    }
}

