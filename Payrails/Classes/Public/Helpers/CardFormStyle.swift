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

// MARK: - Wrapper Style

public struct CardWrapperStyle {
    public let backgroundColor: UIColor?
    public let borderColor: UIColor?
    public let borderWidth: CGFloat?
    public let cornerRadius: CGFloat?
    public let padding: UIEdgeInsets? // Represents layoutMargins

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

    // Default style reflecting the hardcoded values in CardForm init
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

    // Merging logic: self properties override base properties if they exist
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


// MARK: - Styles Configuration

// New main configuration struct for styles
public struct CardFormStylesConfig {
    public let wrapperStyle: CardWrapperStyle? // Style for the outer container
    public let errorTextStyle: CardStyle? // Single style for all error texts
    public let allInputFieldStyles: CardFieldSpecificStyles? // Base style for all input fields
    public let inputFieldStyles: [CardFieldType: CardFieldSpecificStyles]? // Per-field specific overrides
    public let labelStyles: [CardFieldType: CardStyle]? // Per-field label styles

    public init(
        wrapperStyle: CardWrapperStyle? = nil, // Added
        errorTextStyle: CardStyle? = nil,
        allInputFieldStyles: CardFieldSpecificStyles? = nil,
        inputFieldStyles: [CardFieldType : CardFieldSpecificStyles]? = nil,
        labelStyles: [CardFieldType : CardStyle]? = nil
    ) {
        self.wrapperStyle = wrapperStyle // Added
        self.errorTextStyle = errorTextStyle
        self.allInputFieldStyles = allInputFieldStyles
        self.inputFieldStyles = inputFieldStyles
        self.labelStyles = labelStyles
    }

    // Default configuration
    public static var defaultConfig: CardFormStylesConfig {
        // Define default base input styles using CardFieldSpecificStyles
        let defaultAllInputStyle = CardFieldSpecificStyles.defaultStyle
        // Define default label style
        let defaultLabelStyle = CardStyle(textColor: .darkGray) // Changed default label color
        // Define default error style
        let defaultErrorStyle = CardStyle(textColor: UIColor.red)
        // Define default wrapper style
        let defaultWrapperStyle = CardWrapperStyle.defaultStyle // Added

        // Apply default label style to all field types
        var defaultLabelStylesDict: [CardFieldType: CardStyle] = [:]
        let allFieldTypes: [CardFieldType] = [
            .CARD_NUMBER, .CVV, .EXPIRATION_DATE, .EXPIRATION_MONTH, .EXPIRATION_YEAR, .CARDHOLDER_NAME
        ]
        for fieldType in allFieldTypes {
            defaultLabelStylesDict[fieldType] = defaultLabelStyle
        }

        return .init(
            wrapperStyle: defaultWrapperStyle, // Added
            errorTextStyle: defaultErrorStyle,
            allInputFieldStyles: defaultAllInputStyle, // Use the default for all fields
            inputFieldStyles: nil, // No specific overrides by default
            labelStyles: defaultLabelStylesDict
        )
    }
    
    public static var empty: CardFormStylesConfig {
        .init()
    }

     // Merging logic
     public func merged(over base: CardFormStylesConfig?) -> CardFormStylesConfig {
         let baseConfig = base ?? CardFormStylesConfig.empty
         
         // Merge wrapper style
         let finalWrapperStyle = self.wrapperStyle?.merged(over: baseConfig.wrapperStyle) ?? baseConfig.wrapperStyle // Added
         
         // Merge error text style
         let finalErrorTextStyle = self.errorTextStyle?.merged(over: baseConfig.errorTextStyle) ?? baseConfig.errorTextStyle
         
         // Merge all input field styles (self takes priority over base)
         let finalAllInputFieldStyles = self.allInputFieldStyles?.merged(over: baseConfig.allInputFieldStyles) ?? baseConfig.allInputFieldStyles
         
         // Merge specific input field styles
         // Start with base specific styles, then merge self specific styles over them
         var finalInputFieldStyles = baseConfig.inputFieldStyles ?? [:]
         if let selfInputFieldStyles = self.inputFieldStyles {
             for (key, value) in selfInputFieldStyles {
                 // If a style for this key already exists in the merged dict, merge over it
                 // Otherwise, just add the new style
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
             wrapperStyle: finalWrapperStyle, // Added
             errorTextStyle: finalErrorTextStyle,
             allInputFieldStyles: finalAllInputFieldStyles,
             inputFieldStyles: finalInputFieldStyles.isEmpty ? nil : finalInputFieldStyles,
             labelStyles: finalLabelStyles.isEmpty ? nil : finalLabelStyles
         )
     }
    
    // Helper to get the effective input style for a specific field type
    public func effectiveInputStyles(for fieldType: CardFieldType) -> CardFieldSpecificStyles {
        // Start with the base 'all' style, or the default if 'all' is not set
        let baseStyle = self.allInputFieldStyles ?? CardFieldSpecificStyles.defaultStyle
        
        // Check if there's a specific override for this field type
        if let specificStyle = self.inputFieldStyles?[fieldType] {
            // Merge the specific style over the base 'all' style
            return specificStyle.merged(over: baseStyle)
        } else {
            // No specific override, just use the base 'all' style
            return baseStyle
        }
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
