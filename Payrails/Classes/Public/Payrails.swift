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
                values: defaultErrorValues
            )
        )

        // Using the default style here, adjust if needed
        return CardFormConfig(
            style: .defaultStyle,
            showNameField: false,
            fieldConfigs: [ /* Add default field configs if any */ ],
            translations: defaultTranslations
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

        let finalConfig: CardFormConfig
        if let customConfig = config {
            let defaultTranslations = defaultConfig.translations ?? CardTranslations() // Ensure we have a base
            let mergedTranslations = defaultTranslations.merged(with: customConfig.translations)

            finalConfig = CardFormConfig(
                style: customConfig.style,
                showNameField: customConfig.showNameField,
                fieldConfigs: customConfig.fieldConfigs,
                translations: mergedTranslations
            )
        } else {
            // No custom config provided, use the default entirely
            finalConfig = defaultConfig
        }

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
