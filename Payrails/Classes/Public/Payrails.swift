import Foundation
import SwiftUICore
import UIKit

public class Payrails {
    private static var currentSession: Payrails.Session?

    static func configure(
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
    
    // Add a getter method in the main class
    static func getCurrentSession() -> Payrails.Session? {
        return currentSession
    }
}


// Keep existing extensions
public extension Payrails {
    private static func getDefaultCardFormConfig() -> CardFormConfig {
        let defaultTranslations = CardTranslations(
            placeholders: CardTranslations.Placeholders(values: [
                .CARDHOLDER_NAME: "Full Name",
                .CARD_NUMBER: "Card Number",
                .EXPIRATION_DATE: "MM/YY", // Default uses MM/YY usually
                .CVV: "CVV",
                .EXPIRATION_MONTH: "MM",   // Add defaults if needed
                .EXPIRATION_YEAR: "YYYY"  // Add defaults if needed
            ]),
            labels: CardTranslations.Labels(
                values: [
                    .CARDHOLDER_NAME: "Name on Card",
                    .CARD_NUMBER: "Card Number",
                    .EXPIRATION_DATE: "Expiry Date",
                    .CVV: "Security Code",
                    .EXPIRATION_MONTH: "Expiry Month", // Add defaults if needed
                    .EXPIRATION_YEAR: "Expiry Year"   // Add defaults if needed
                ],
                saveInstrument: "Save card",
                storeInstrument: "Remember card",
                paymentInstallments: "Pay in installments"
            ),
            error: CardTranslations.ErrorMessages(
                defaultErrors: CardTranslations.ErrorMessages.DefaultErrors(values: [
                    .CARDHOLDER_NAME: "Enter name as it appears on card",
                    .CARD_NUMBER: "Enter a valid card number",
                    .EXPIRATION_DATE: "Enter a valid expiry date (MM/YY)",
                    .CVV: "Enter the 3 or 4 digit code",
                    .EXPIRATION_MONTH: "Enter a valid month",   // Add defaults if needed
                    .EXPIRATION_YEAR: "Enter a valid year"     // Add defaults if needed
                ])
            )
        )

        // Using the default style here, adjust if needed
        return CardFormConfig(
            style: .defaultStyle,
            showNameField: true,
            fieldConfigs: [ /* Add default field configs if any */ ],
            translations: defaultTranslations // Provide the default translations
        )
    }
    
    static func configure(
        with configuration: Payrails.Configuration
    ) async throws -> Payrails.Session {
        let result = try await withCheckedThrowingContinuation({ continuation in
            Payrails.configure(with: configuration) { result in
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
    
    static func createCardPaymentForm(
        config: CardFormConfig? = nil, // Accept optional custom config
        buttonTitle: String = "Pay Now"
    ) -> Payrails.CardPaymentForm {

        precondition(currentSession != nil, "Payrails session must be initialized before creating a CardPaymentForm")

        let session = currentSession!
        let defaultConfig = getDefaultCardFormConfig() // Get the base default config

        // --- Merging Logic ---
        let finalConfig: CardFormConfig
        if let customConfig = config {
            // Merge provided config with default, focusing on translations for now
            
            // Merge translations: default merged with custom (custom takes priority)
            // Handle cases where default or custom translations might be nil
            let defaultTranslations = defaultConfig.translations ?? CardTranslations() // Ensure we have a base
            let mergedTranslations = defaultTranslations.merged(with: customConfig.translations)

            // For other properties, currently, we just take the custom ones if provided.
            // You could expand this merging logic to style, showNameField etc. if needed later.
            finalConfig = CardFormConfig(
                style: customConfig.style, // Takes custom style completely (or default if custom didn't set one)
                showNameField: customConfig.showNameField, // Takes custom setting
                fieldConfigs: customConfig.fieldConfigs, // Takes custom field configs
                translations: mergedTranslations // Use the merged translations
            )
        } else {
            // No custom config provided, use the default entirely
            finalConfig = defaultConfig
        }
        // --- End Merging Logic ---

        // Create the combined CardPaymentForm using the finalConfig
        let cardPaymentForm = Payrails.CardPaymentForm(
            config: finalConfig, // Use the potentially merged config
            tableName: "tableName", // Keep as is for now
            cseConfig: (data: "", version: ""), // Keep as is for now
            holderReference: session.getSDKConfiguration()!.holderRefecerence,
            cseInstance: session.getCSEInstance()!,
            session: session,
            buttonTitle: buttonTitle
        )

        return cardPaymentForm
    }
    
    static func createPayPalButton() -> Payrails.PayPalButton {
        precondition(currentSession != nil, "Payrails session must be initialized before creating a PayPalButton")
        let session = currentSession!
        // Calls the new internal initializer passing the session
        let button = Payrails.PayPalButton(session: session)
        return button
    }
}

public extension Payrails {
    struct Debug {
        public static func configViewer(session: Payrails.Session) -> some View {
            SimplePayrailsViewer(config: session.debugConfig)
        }
    }
}
