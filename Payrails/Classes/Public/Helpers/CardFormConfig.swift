//
//  CardFormConfig.swift
//  Pods
//
//  Created by Mustafa Dikici on 23.04.25.
//
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
