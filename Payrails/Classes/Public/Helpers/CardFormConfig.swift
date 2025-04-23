//
//  CardFormConfig.swift
//  Pods
//
//  Created by Mustafa Dikici on 23.04.25.
//
//
//  CardFormConfig.swift
//  Pods
//
//  Created by Mustafa Dikici on 23.04.25.
//
public struct CardFormConfig {
    public let showNameField: Bool
    public let translations: CardTranslations?
    // Use the new styles config struct
    public let styles: CardFormStylesConfig? // Changed from [CardFieldType: CardFormStyle]?

    public init(
        showNameField: Bool = false,
        // Update initializer parameter
        styles: CardFormStylesConfig? = nil, // Changed type
        translations: CardTranslations? = nil
    ) {
        self.showNameField = showNameField
        // Merge provided translations over defaults if needed, or handle defaults elsewhere
        self.translations = translations // Assuming defaults are handled at usage or within CardTranslations
        // Merge provided styles over defaults
        self.styles = styles?.merged(over: CardFormStylesConfig.defaultConfig) ?? CardFormStylesConfig.defaultConfig
    }

    // Default config now uses the new styles default and potentially default translations
    public static var defaultConfig: CardFormConfig {
        // Use the default from the new styles config struct
        let defaultStyles = CardFormStylesConfig.defaultConfig
        // Consider adding default translations here if desired
        // let defaultTranslations = CardTranslations(...)

        return .init(
            showNameField: true,
            styles: defaultStyles, // Use the new default styles
            translations: nil // Or use defaultTranslations
        )
    }
    
    // Convenience initializer to maintain backward compatibility or ease of use with old style format (optional)
    // This would convert the old format to the new one internally.
    /*
    public init(
        showNameField: Bool = false,
        legacyStyles: [CardFieldType: CardFormStyle]? = nil, // Old format
        translations: CardTranslations? = nil
    ) {
        self.showNameField = showNameField
        self.translations = translations
        
        // Convert legacyStyles to CardFormStylesConfig
        if let legacyStyles = legacyStyles {
            var inputStylesDict: [CardFieldType: CardFieldSpecificStyles] = [:]
            var labelStylesDict: [CardFieldType: CardStyle] = [:]
            // Assuming a single error text style from the first legacy style found (or a default)
            let errorTextStyle = legacyStyles.first?.value.errorTextStyle

            for (type, legacyStyle) in legacyStyles {
                inputStylesDict[type] = CardFieldSpecificStyles(
                    base: legacyStyle.baseStyle,
                    focus: legacyStyle.focusStyle,
                    completed: legacyStyle.completedStyle,
                    invalid: legacyStyle.invalidStyle
                )
                labelStylesDict[type] = legacyStyle.labelStyle
            }
            
            let convertedStyles = CardFormStylesConfig(
                errorTextStyle: errorTextStyle,
                inputFieldStyles: inputStylesDict,
                labelStyles: labelStylesDict
            )
            self.styles = convertedStyles.merged(over: CardFormStylesConfig.defaultConfig)
        } else {
            self.styles = CardFormStylesConfig.defaultConfig
        }
    }
     */
}
