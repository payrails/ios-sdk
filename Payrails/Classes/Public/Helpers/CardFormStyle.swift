import UIKit // Ensure UIKit is imported for UIEdgeInsets etc.

public typealias CardStyle = Style
public typealias CardFieldType = ElementType

// MARK: - New Style Structures (Proposed)

// New struct for input field specific styles
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

    // Merging logic might be needed here as well if defaults are used
    // func merged(over base: CardFieldSpecificStyles?) -> CardFieldSpecificStyles { ... }

    // Default instance (can be customized)
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

// New main configuration struct for styles
public struct CardFormStylesConfig {
    public let errorTextStyle: CardStyle? // Single style for all error texts
    public let inputFieldStyles: [CardFieldType: CardFieldSpecificStyles]? // Per-field input styles
    public let labelStyles: [CardFieldType: CardStyle]? // Per-field label styles

    public init(
        errorTextStyle: CardStyle? = nil,
        inputFieldStyles: [CardFieldType : CardFieldSpecificStyles]? = nil,
        labelStyles: [CardFieldType : CardStyle]? = nil
    ) {
        self.errorTextStyle = errorTextStyle
        self.inputFieldStyles = inputFieldStyles
        self.labelStyles = labelStyles
    }

    // Default configuration
    public static var defaultConfig: CardFormStylesConfig {
        // Define default input styles using CardFieldSpecificStyles
        let defaultInputStyle = CardFieldSpecificStyles.defaultStyle
        // Define default label style
        let defaultLabelStyle = CardStyle(textColor: .darkGray) // Changed default label color
        // Define default error style
        let defaultErrorStyle = CardStyle(textColor: UIColor.red)

        // Apply defaults to all field types
        var defaultInputStylesDict: [CardFieldType: CardFieldSpecificStyles] = [:]
        var defaultLabelStylesDict: [CardFieldType: CardStyle] = [:]

        // Ensure all relevant field types are covered
        let allFieldTypes: [CardFieldType] = [
            .CARD_NUMBER, .CVV, .EXPIRATION_DATE, .EXPIRATION_MONTH, .EXPIRATION_YEAR, .CARDHOLDER_NAME
        ]
        for fieldType in allFieldTypes {
            defaultInputStylesDict[fieldType] = defaultInputStyle
            defaultLabelStylesDict[fieldType] = defaultLabelStyle
        }

        return .init(
            errorTextStyle: defaultErrorStyle,
            inputFieldStyles: defaultInputStylesDict,
            labelStyles: defaultLabelStylesDict
        )
    }
    
    public static var empty: CardFormStylesConfig {
        .init()
    }

     // Merging logic
     public func merged(over base: CardFormStylesConfig?) -> CardFormStylesConfig {
         let baseConfig = base ?? CardFormStylesConfig.empty
         
         // Merge error text style
         let finalErrorTextStyle = self.errorTextStyle?.merged(over: baseConfig.errorTextStyle) ?? baseConfig.errorTextStyle
         
         // Merge input field styles
         var finalInputFieldStyles = baseConfig.inputFieldStyles ?? [:]
         if let selfInputFieldStyles = self.inputFieldStyles {
             for (key, value) in selfInputFieldStyles {
                 finalInputFieldStyles[key] = value.merged(over: finalInputFieldStyles[key])
             }
         }
         
         // Merge label styles
         var finalLabelStyles = baseConfig.labelStyles ?? [:]
         if let selfLabelStyles = self.labelStyles {
             for (key, value) in selfLabelStyles {
                 finalLabelStyles[key] = value.merged(over: finalLabelStyles[key])
             }
         }

         return .init(
             errorTextStyle: finalErrorTextStyle,
             inputFieldStyles: finalInputFieldStyles.isEmpty ? nil : finalInputFieldStyles,
             labelStyles: finalLabelStyles.isEmpty ? nil : finalLabelStyles
         )
     }
}


// MARK: - Original Style Structure (Potentially Deprecated)

// Consider making this internal or removing if CardFormStylesConfig fully replaces its public role.
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
