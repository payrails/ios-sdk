import UIKit

public typealias CardStyle = Style
public typealias CardFieldType = ElementType

public struct CardFieldSpecificStyles {
    public let base: CardStyle?
    public let focus: CardStyle?
    public let completed: CardStyle?
    public let invalid: CardStyle?

    public init(base: CardStyle? = nil, focus: CardStyle? = nil, completed: CardStyle? = nil, invalid: CardStyle? = nil) {
        self.base = base
        self.focus = focus
        self.completed = completed
        self.invalid = invalid
    }

    // Helper to convert to Skyflow's Styles object
    var skyflowStyles: Styles {
        Styles(
            base: base,
            complete: completed,
            focus: focus,
            invalid: invalid
        )
    }

    public static var defaultStyle: CardFieldSpecificStyles {
        .init(
            base: .init(cornerRadius: 2, padding: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10), borderWidth: 1, textAlignment: .left, textColor: .black), // Changed default text color
            focus: .init(borderColor: .blue),
            completed: .init(borderColor: .green),
            invalid: .init(borderColor: .red)
        )
    }
    
    public static var empty: CardFieldSpecificStyles {
        .init()
    }
    
    public func merged(over base: CardFieldSpecificStyles?) -> CardFieldSpecificStyles {
        let baseStyle = base ?? CardFieldSpecificStyles.empty
        return CardFieldSpecificStyles(
            base: self.base?.merged(over: baseStyle.base) ?? baseStyle.base,
            focus: self.focus?.merged(over: baseStyle.focus) ?? baseStyle.focus,
            completed: self.completed?.merged(over: baseStyle.completed) ?? baseStyle.completed,
            invalid: self.invalid?.merged(over: baseStyle.invalid) ?? baseStyle.invalid
        )
    }
}

public struct CardButtonStyle {
    public let backgroundColor: UIColor?
    public let textColor: UIColor?
    public let font: UIFont?
    public let cornerRadius: CGFloat?
    public let borderWidth: CGFloat?
    public let borderColor: UIColor?
    public let contentEdgeInsets: UIEdgeInsets?

    public init(
        backgroundColor: UIColor? = nil,
        textColor: UIColor? = nil,
        font: UIFont? = nil,
        cornerRadius: CGFloat? = nil,
        borderWidth: CGFloat? = nil,
        borderColor: UIColor? = nil,
        contentEdgeInsets: UIEdgeInsets? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.font = font
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.contentEdgeInsets = contentEdgeInsets
    }

    public static var defaultStyle: CardButtonStyle {
        .init(
            backgroundColor: .systemBlue,
            textColor: .white,
            cornerRadius: 8.0,
            contentEdgeInsets: nil
        )
    }

    public static var empty: CardButtonStyle {
        .init()
    }

    public func merged(over base: CardButtonStyle?) -> CardButtonStyle {
        let baseStyle = base ?? CardButtonStyle.empty
        return CardButtonStyle(
            backgroundColor: self.backgroundColor ?? baseStyle.backgroundColor,
            textColor: self.textColor ?? baseStyle.textColor,
            font: self.font ?? baseStyle.font,
            cornerRadius: self.cornerRadius ?? baseStyle.cornerRadius,
            borderWidth: self.borderWidth ?? baseStyle.borderWidth,
            borderColor: self.borderColor ?? baseStyle.borderColor,
            contentEdgeInsets: self.contentEdgeInsets ?? baseStyle.contentEdgeInsets
        )
    }
}


public struct CardWrapperStyle {
    public let backgroundColor: UIColor?
    public let borderColor: UIColor?
    public let borderWidth: CGFloat?
    public let cornerRadius: CGFloat?
    public let padding: UIEdgeInsets?

    public init(
        backgroundColor: UIColor? = nil,
        borderColor: UIColor? = nil,
        borderWidth: CGFloat? = nil,
        cornerRadius: CGFloat? = nil,
        padding: UIEdgeInsets? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    public static var defaultStyle: CardWrapperStyle {
        .init(
            borderColor: UIColor.gray,
            borderWidth: 1.0,
            cornerRadius: 8.0,
            padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        )
    }

    public static var empty: CardWrapperStyle {
        .init()
    }

    public func merged(over base: CardWrapperStyle?) -> CardWrapperStyle {
        let baseStyle = base ?? CardWrapperStyle.empty
        return CardWrapperStyle(
            backgroundColor: self.backgroundColor ?? baseStyle.backgroundColor,
            borderColor: self.borderColor ?? baseStyle.borderColor,
            borderWidth: self.borderWidth ?? baseStyle.borderWidth,
            cornerRadius: self.cornerRadius ?? baseStyle.cornerRadius,
            padding: self.padding ?? baseStyle.padding
        )
    }
}


public struct CardFormStylesConfig {
    public let wrapperStyle: CardWrapperStyle?
    public let errorTextStyle: CardStyle?
    public let allInputFieldStyles: CardFieldSpecificStyles?
    public let inputFieldStyles: [CardFieldType: CardFieldSpecificStyles]?
    public let labelStyles: [CardFieldType: CardStyle]?
    public let buttonStyle: CardButtonStyle?

    public init(
        wrapperStyle: CardWrapperStyle? = nil,
        errorTextStyle: CardStyle? = nil,
        allInputFieldStyles: CardFieldSpecificStyles? = nil,
        inputFieldStyles: [CardFieldType : CardFieldSpecificStyles]? = nil,
        labelStyles: [CardFieldType : CardStyle]? = nil,
        buttonStyle: CardButtonStyle? = nil
    ) {
        self.wrapperStyle = wrapperStyle
        self.errorTextStyle = errorTextStyle
        self.allInputFieldStyles = allInputFieldStyles
        self.inputFieldStyles = inputFieldStyles
        self.labelStyles = labelStyles
        self.buttonStyle = buttonStyle
    }


    public static var defaultConfig: CardFormStylesConfig {
        let defaultAllInputStyle = CardFieldSpecificStyles.defaultStyle
        let defaultLabelStyle = CardStyle(textColor: .darkGray)
        let defaultErrorStyle = CardStyle(textColor: UIColor.red)
        let defaultWrapperStyle = CardWrapperStyle.defaultStyle
        let defaultButtonStyle = CardButtonStyle.defaultStyle // Added

        var defaultLabelStylesDict: [CardFieldType: CardStyle] = [:]
        let allFieldTypes: [CardFieldType] = [
            .CARD_NUMBER, .CVV, .EXPIRATION_DATE, .EXPIRATION_MONTH, .EXPIRATION_YEAR, .CARDHOLDER_NAME
        ]
        for fieldType in allFieldTypes {
            defaultLabelStylesDict[fieldType] = defaultLabelStyle
        }

        return .init(
            wrapperStyle: defaultWrapperStyle,
            errorTextStyle: defaultErrorStyle,
            allInputFieldStyles: defaultAllInputStyle,
            inputFieldStyles: nil,
            labelStyles: defaultLabelStylesDict,
            buttonStyle: defaultButtonStyle
        )
    }
    
    public static var empty: CardFormStylesConfig {
        .init()
    }

     public func merged(over base: CardFormStylesConfig?) -> CardFormStylesConfig {
         let baseConfig = base ?? CardFormStylesConfig.empty

         let finalWrapperStyle = self.wrapperStyle?.merged(over: baseConfig.wrapperStyle) ?? baseConfig.wrapperStyle

         let finalErrorTextStyle = self.errorTextStyle?.merged(over: baseConfig.errorTextStyle) ?? baseConfig.errorTextStyle
         
         let finalAllInputFieldStyles = self.allInputFieldStyles?.merged(over: baseConfig.allInputFieldStyles) ?? baseConfig.allInputFieldStyles
         
         var finalInputFieldStyles = baseConfig.inputFieldStyles ?? [:]
         if let selfInputFieldStyles = self.inputFieldStyles {
             for (key, value) in selfInputFieldStyles {
                 finalInputFieldStyles[key] = value.merged(over: finalInputFieldStyles[key])
             }
         }
         
         var finalLabelStyles = baseConfig.labelStyles ?? [:]
         if let selfLabelStyles = self.labelStyles {
             for (key, value) in selfLabelStyles {
                 finalLabelStyles[key] = value.merged(over: finalLabelStyles[key])
             }
         }

         return .init(
             wrapperStyle: finalWrapperStyle,
             errorTextStyle: finalErrorTextStyle,
             allInputFieldStyles: finalAllInputFieldStyles,
             inputFieldStyles: finalInputFieldStyles.isEmpty ? nil : finalInputFieldStyles,
             labelStyles: finalLabelStyles.isEmpty ? nil : finalLabelStyles,
             buttonStyle: self.buttonStyle?.merged(over: baseConfig.buttonStyle) ?? baseConfig.buttonStyle // Added
         )
     }
    
    public func effectiveInputStyles(for fieldType: CardFieldType) -> CardFieldSpecificStyles {
        let baseStyle = self.allInputFieldStyles ?? CardFieldSpecificStyles.defaultStyle
        
        if let specificStyle = self.inputFieldStyles?[fieldType] {
            return specificStyle.merged(over: baseStyle)
        } else {
            return baseStyle
        }
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
