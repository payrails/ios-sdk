import Foundation
import SwiftUICore
import UIKit
import PassKit


public class Payrails {
    private static var currentSession: Payrails.Session?
    private static var currentCardForm: Payrails.CardForm?


    static func createSession(
        with configuration: Payrails.Configuration,
        onInit: OnInitCallback
    ) {
        do {
            let payrailsSession = try Payrails.Session(
                configuration
            )
            currentSession = payrailsSession
            onInit(.success(payrailsSession))
        } catch {
            onInit(
                .failure(
                    PayrailsError.unknown(error: error)
                )
            )
        }
    }
    
    static func getCurrentSession() -> Payrails.Session? {
        return currentSession
    }

    // MARK: - SDK Logging
    public static func log(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, function: String = #function, line: UInt = #line) {
        
        let output = items.map { "\($0)" }.joined(separator: separator)
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) -> \(output)"
        
        // 1. Print to console (for Xcode debugging)
        Swift.print(logMessage, terminator: terminator)
        
        // 2. Add to our on-screen LogStore
        // Ensure this is thread-safe if called from various parts of the SDK
        LogStore.shared.addLog(logMessage)
        
    }
}


public extension Payrails {
    private static func getDefaultCardFormConfig() -> CardFormConfig {
        let defaultErrorValues: [CardFieldType: String] = [
             .CARDHOLDER_NAME: "Enter name as it appears on card",
             .CARD_NUMBER: "Enter a valid card number",
             .EXPIRATION_DATE: "Enter a valid expiry date (MM/YY)",
             .CVV: "Enter the 3 or 4 digit code",
             .EXPIRATION_MONTH: "Enter a valid month",
             .EXPIRATION_YEAR: "Enter a valid year"
        ]
        
        let defaultTranslations = CardTranslations(
            placeholders: CardTranslations.Placeholders(values: [
                .CARDHOLDER_NAME: "Full Name",
                .CARD_NUMBER: "Card Number",
                .EXPIRATION_DATE: "MM/YY",
                .CVV: "CVV",
                .EXPIRATION_MONTH: "MM",
                .EXPIRATION_YEAR: "YYYY"
            ]),
            labels: CardTranslations.Labels(
                saveInstrument: "Save card",
                storeInstrument: "Remember card",
                paymentInstallments: "Pay in installments"
            ),
            error: CardTranslations.ErrorMessages(
                values: defaultErrorValues
            )
        )

        return CardFormConfig(
            showNameField: false,
            translations: defaultTranslations
        )
    }
    
    static func createSession(
        with configuration: Payrails.Configuration
    ) async throws -> Payrails.Session {
        let result = try await withCheckedThrowingContinuation({ continuation in
            Payrails.createSession(with: configuration) { result in
                switch result {
                case let .success(session):
                    continuation.resume(returning: session)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        })
        return result
    }
    
    static func createPayPalButton(showSaveInstrument: Bool = false) -> PaypalElement {
        precondition(currentSession != nil, "Payrails session must be initialized before creating a PayPalButton")
        let session = currentSession!

        if showSaveInstrument {
            Payrails.log("Creating paypal button with toggle")
            let button = Payrails.PayPalButtonWithToggle(session: session, showSaveInstrument: true)
            return button
        } else {
            Payrails.log("Creating paypal button")
            let button = Payrails.PayPalButton(session: session)
            return button
        }
    }
    
    static func createApplePayButton(type: PKPaymentButtonType, style: PKPaymentButtonStyle, showSaveInstrument: Bool = false) -> ApplePayElement {
        Payrails.log("Creating apple pay button")
        precondition(currentSession != nil, "Payrails session must be initialized before creating an ApplePayButton")
        let session = currentSession!
        
        if showSaveInstrument {
            Payrails.log("Creating apple pay button with toggle")
            let button = Payrails.ApplePayButtonWithToggle(session: session, showSaveInstrument: true, type: type, style: style)
            return button
        } else {
            let button = Payrails.ApplePayButton(session: session, type: type, style: style)
            return button
        }
    }
    
    static func createCardPaymentButton(
        buttonStyle: CardButtonStyle? = nil,
        translations: CardPaymenButtonTranslations
    ) -> Payrails.CardPaymentButton {
        precondition(currentSession != nil, "Payrails session must be initialized before creating a CardPaymentButton")
        precondition(currentCardForm != nil, "A card form must be created with createCardForm() before creating a CardPaymentButton")
        
        let session = currentSession!
        let cardForm = currentCardForm!

        
        let button = Payrails.CardPaymentButton(
            cardForm: cardForm,
            session: session,
            translations: translations,
            buttonStyle: buttonStyle
        )
        
        return button
    }
    
    // New factory method for stored instrument mode
    static func createCardPaymentButton(
        storedInstrument: StoredInstrument,
        buttonStyle: StoredInstrumentButtonStyle? = nil,
        translations: CardPaymenButtonTranslations,
        storedInstrumentTranslations: StoredInstrumentButtonTranslations? = nil
    ) -> Payrails.CardPaymentButton {
        precondition(currentSession != nil, "Payrails session must be initialized before creating a CardPaymentButton")
        
        let session = currentSession!
        
        let button = Payrails.CardPaymentButton(
            storedInstrument: storedInstrument,
            session: session,
            translations: translations,
            storedInstrumentTranslations: storedInstrumentTranslations,
            buttonStyle: buttonStyle
        )
        
        return button
    }
    
    
    static func createCardForm(
        config: CardFormConfig? = nil,
        showSaveInstrument: Bool = false
    ) -> Payrails.CardForm {
        precondition(currentSession != nil, "Payrails session must be initialized before creating a CardForm")
        
        let session = currentSession!
        let defaultConfig = getDefaultCardFormConfig()
        let defaultStylesConfig = defaultConfig.styles ?? CardFormStylesConfig.defaultConfig
        
        let finalConfig: CardFormConfig
        if let customConfig = config {
            let finalStylesConfig = customConfig.styles?.merged(over: defaultStylesConfig) ?? defaultStylesConfig
            
            let defaultTranslations = defaultConfig.translations ?? CardTranslations()
            let finalTranslations = defaultTranslations.merged(with: customConfig.translations)
            
            finalConfig = CardFormConfig(
                showNameField: customConfig.showNameField,
                showSaveInstrument: showSaveInstrument,
                styles: finalStylesConfig,
                translations: finalTranslations
            )
        } else {
            finalConfig = CardFormConfig(
                showNameField: defaultConfig.showNameField,
                showSaveInstrument: showSaveInstrument,
                styles: defaultConfig.styles,
                translations: defaultConfig.translations
            )
        }
        
        guard let cseInstance = session.getCSEInstance(),
              let holderReference = session.getSDKConfiguration()?.holderRefecerence else {
            fatalError("CSE instance or holder reference not available in session.")
        }
        
        let cardForm = Payrails.CardForm(
            config: finalConfig,
            tableName: "tableName",
            cseConfig: (data: "", version: ""),
            holderReference: holderReference,
            cseInstance: cseInstance
        )
        
        currentCardForm = cardForm
        
        return cardForm
    }
    
    static func createGenericRedirectButton(
        buttonStyle: CardButtonStyle? = nil,
        translations: CardPaymenButtonTranslations,
        paymentMethodCode: String
    ) -> Payrails.GenericRedirectButton {
        let session = currentSession!
        let button = Payrails.GenericRedirectButton(
            paymentMethodCode: paymentMethodCode,
            session: session,
            translations: translations
        )
        
        if let style = buttonStyle {
            if let bgColor = style.backgroundColor {
                button.backgroundColor = bgColor
            }
            if let textColor = style.textColor {
                button.setTitleColor(textColor, for: .normal)
            }
            if let font = style.font {
                button.titleLabel?.font = font
            }
            if let cornerRadius = style.cornerRadius {
                button.layer.cornerRadius = cornerRadius
                button.layer.masksToBounds = cornerRadius > 0
            }
            if let borderWidth = style.borderWidth {
                button.layer.borderWidth = borderWidth
            }
            if let borderColor = style.borderColor {
                button.layer.borderColor = borderColor.cgColor
            }
            if let insets = style.contentEdgeInsets {
                button.contentEdgeInsets = insets
            }
        }
        
        return button
    }
    
    static func createStoredInstruments(
        style: StoredInstrumentsStyle? = nil,
        translations: StoredInstrumentsTranslations? = nil,
        showDeleteButton: Bool = false,
        showPayButton: Bool = false
    ) -> Payrails.StoredInstruments {
        precondition(currentSession != nil, "Payrails session must be initialized before creating StoredInstruments")
        
        let session = currentSession!
        let finalStyle = style ?? StoredInstrumentsStyle.defaultStyle
        let finalTranslations = translations ?? StoredInstrumentsTranslations()
        
        let storedInstruments = Payrails.StoredInstruments(
            session: session,
            style: finalStyle,
            translations: finalTranslations,
            showDeleteButton: showDeleteButton,
            showPayButton: showPayButton
        )
        
        return storedInstruments
    }
    
    static func createStoredInstrumentView(
        instrument: StoredInstrument,
        style: StoredInstrumentsStyle? = nil,
        translations: StoredInstrumentsTranslations? = nil,
        showDeleteButton: Bool = false,
        showPayButton: Bool = false
    ) -> Payrails.StoredInstrumentView {
        precondition(currentSession != nil, "Payrails session must be initialized before creating StoredInstrumentView")
        
        let session = currentSession!
        let finalStyle = style ?? StoredInstrumentsStyle.defaultStyle
        let finalTranslations = translations ?? StoredInstrumentsTranslations()
        
        let storedInstrumentView = Payrails.StoredInstrumentView(
            instrument: instrument,
            session: session,
            style: finalStyle,
            translations: finalTranslations,
            showDeleteButton: showDeleteButton,
            showPayButton: showPayButton
        )
        
        return storedInstrumentView
    }
    
    static func deleteInstrument(instrumentId: String) async throws -> DeleteInstrumentResponse {
        guard let currentSession = getCurrentSession() else {
            throw PayrailsError.missingData("No active Payrails session. Please initialize a session first.")
        }
        
        return try await currentSession.deleteInstrument(instrumentId: instrumentId)
    }
    
    static func updateInstrument(instrumentId: String, body: UpdateInstrumentBody) async throws -> UpdateInstrumentResponse {
        guard let currentSession = getCurrentSession() else {
            throw PayrailsError.missingData("No active Payrails session. Please initialize a session first.")
        }
        
        return try await currentSession.updateInstrument(instrumentId: instrumentId, body: body)
    }
    
    static func getStoredInstruments() -> [StoredInstrument] {
        guard let currentSession = getCurrentSession() else {
            Payrails.log("No active Payrails session available for getting stored instruments")
            return []
        }
        
        // Get all stored instruments (both card and PayPal)
        let cardInstruments = currentSession.storedInstruments(for: .card)
        let paypalInstruments = currentSession.storedInstruments(for: .payPal)
        let allInstruments = cardInstruments + paypalInstruments
        
        Payrails.log("Retrieved \(allInstruments.count) stored instruments (\(cardInstruments.count) cards, \(paypalInstruments.count) PayPal)")
        
        return allInstruments
    }
    
    static func getStoredInstruments(for type: Payrails.PaymentType) -> [StoredInstrument] {
        guard let currentSession = getCurrentSession() else {
            Payrails.log("No active Payrails session available for getting stored instruments")
            return []
        }
        
        let instruments = currentSession.storedInstruments(for: type)
        Payrails.log("Retrieved \(instruments.count) stored instruments for type: \(type.rawValue)")
        
        return instruments
    }
}

public extension Payrails {
    struct Debug {
        public static func configViewer(session: Payrails.Session) -> some View {
            SimplePayrailsViewer(config: session.debugConfig)
        }
    }
}
