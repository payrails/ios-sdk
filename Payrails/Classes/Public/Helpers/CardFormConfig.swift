//
//  CardFormConfig.swift
//  Pods
//
//  Created by Mustafa Dikici on 23.04.25.
//
//
public struct CardFormConfig {
    public let showNameField: Bool
    public let translations: CardTranslations?
    
    public let styles: CardFormStylesConfig?

    public init(
        showNameField: Bool = false,
        styles: CardFormStylesConfig? = nil,
        translations: CardTranslations? = nil
    ) {
        self.showNameField = showNameField
        self.translations = translations
        self.styles = styles?.merged(over: CardFormStylesConfig.defaultConfig) ?? CardFormStylesConfig.defaultConfig
    }

    public static var defaultConfig: CardFormConfig {
        let defaultStyles = CardFormStylesConfig.defaultConfig

        return .init(
            showNameField: true,
            styles: defaultStyles,
            translations: nil
        )
    }
    
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
