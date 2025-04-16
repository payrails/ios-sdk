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
    
    static func getCurrentSession() -> Payrails.Session? {
        return currentSession
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
                values: [
                    .CARDHOLDER_NAME: "Name on Card",
                    .CARD_NUMBER: "Card Number",
                    .EXPIRATION_DATE: "Expiry Date",
                    .CVV: "Security Code",
                    .EXPIRATION_MONTH: "Expiry Month",
                    .EXPIRATION_YEAR: "Expiry Year"
                ],
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
        config: CardFormConfig? = nil,
        buttonTitle: String = "Pay Now"
    ) -> Payrails.CardPaymentForm {

        precondition(currentSession != nil, "Payrails session must be initialized before creating a CardPaymentForm")

        let session = currentSession!
        let defaultConfig = getDefaultCardFormConfig()
        let defaultStyles = defaultConfig.styles ?? [:]

        let finalConfig: CardFormConfig
        if let customConfig = config {
            var mergedStyles = defaultStyles
            if let customStyles = customConfig.styles {
                 for (fieldType, customFieldStyle) in customStyles {
                     // Get the default style for this specific field type
                     let baseFieldStyle = defaultStyles[fieldType] // Might be nil if type not in defaults
                     // Merge the user's custom style over the default for that field
                     mergedStyles[fieldType] = customFieldStyle.merged(over: baseFieldStyle)
                 }
            }
            let defaultTranslations = defaultConfig.translations ?? CardTranslations()
            let mergedTranslations = defaultTranslations.merged(with: customConfig.translations)

            finalConfig = CardFormConfig(
                showNameField: customConfig.showNameField,
                styles: mergedStyles,
                translations: mergedTranslations
            )
        } else {
            finalConfig = defaultConfig
        }

        let cardPaymentForm = Payrails.CardPaymentForm(
            config: finalConfig,
            tableName: "tableName",
            cseConfig: (data: "", version: ""),
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
