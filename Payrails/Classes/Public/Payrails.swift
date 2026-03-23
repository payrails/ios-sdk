import Foundation
import SwiftUI
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
}

public extension Payrails {
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
        let defaultConfig = CardForm.defaultConfig
        let defaultStylesConfig = defaultConfig.styles ?? CardFormStylesConfig.defaultConfig

        let finalConfig: CardFormConfig
        if let customConfig = config {
            let finalStylesConfig = customConfig.styles?.merged(over: defaultStylesConfig) ?? defaultStylesConfig

            let defaultTranslations = defaultConfig.translations ?? CardTranslations()
            let finalTranslations = defaultTranslations.merged(with: customConfig.translations)

            finalConfig = CardFormConfig(
                showNameField: customConfig.showNameField,
                showSaveInstrument: showSaveInstrument,
                showCardIcon: customConfig.showCardIcon,
                showRequiredAsterisk: customConfig.showRequiredAsterisk,
                cardIconAlignment: customConfig.cardIconAlignment,
                fieldVariant: customConfig.fieldVariant,
                layout: customConfig.layout,
                styles: finalStylesConfig,
                translations: finalTranslations
            )
        } else {
            finalConfig = CardFormConfig(
                showNameField: defaultConfig.showNameField,
                showSaveInstrument: showSaveInstrument,
                showCardIcon: defaultConfig.showCardIcon,
                showRequiredAsterisk: defaultConfig.showRequiredAsterisk,
                cardIconAlignment: defaultConfig.cardIconAlignment,
                layout: defaultConfig.layout,
                styles: defaultConfig.styles,
                translations: defaultConfig.translations
            )
        }

        let cardForm = Payrails.CardForm(
            config: finalConfig,
            session: session
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
        showUpdateButton: Bool = false,
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
            showUpdateButton: showUpdateButton,
            showPayButton: showPayButton
        )

        return storedInstruments
    }

    static func api(_ operation: String, _ instrumentId: String, _ body: UpdateInstrumentBody? = nil) async throws -> InstrumentAPIResponse {
        guard let currentSession = getCurrentSession() else {
            throw PayrailsError.missingData("No active Payrails session. Please initialize a session first.")
        }

        switch operation {
        case "deleteInstrument":
            let response = try await currentSession.deleteInstrument(instrumentId: instrumentId)
            return .delete(response)
        case "updateInstrument":
            guard let body = body else {
                throw PayrailsError.missingData("UpdateInstrumentBody is required for updateInstrument operation")
            }
            let response = try await currentSession.updateInstrument(instrumentId: instrumentId, body: body)
            return .update(response)
        default:
            throw PayrailsError.invalidDataFormat
        }
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

    static func update(_ options: UpdateOptions) {
        guard let session = getCurrentSession() else {
            Payrails.log("No active Payrails session. Call createSession() before update().")
            return
        }
        session.update(options)
    }
}

public extension Payrails {
    struct Debug {
        public static func configViewer() -> some View {
            precondition(Payrails.getCurrentSession() != nil, "Payrails session must be initialized before using configViewer")
            return SimplePayrailsViewer(config: Payrails.getCurrentSession()!.debugConfig)
        }
    }
}

public extension Payrails {
    /// Query the SDK for configuration and session state.
    /// Mirrors the web SDK's `payrails.query(key, params)` API.
    /// Requires a session to be initialized via `Payrails.configure(...)`.
    static func query(_ key: PayrailsQueryKey) -> PayrailsQueryResult? {
        return currentSession?.query(key)
    }
}
