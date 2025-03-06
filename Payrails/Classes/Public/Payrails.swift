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
    
    static func createCardForm(
        config: CardFormConfig = CardFormConfig(showNameField: false, fieldConfigs: [])
    ) -> Payrails.CardForm {
        precondition(currentSession != nil, "Payrails session must be initialized before creating a CardPaymentForm")
        let session = currentSession!
        
        let defaultCardFormConfig = CardFormConfig(
            showNameField: false,
            fieldConfigs: [
                CardFieldConfig(
                    type: .CARD_NUMBER,
                    placeholder: "1234 5678 9012 3456",
                    title: "Card Number",
                    style: CardFormStyle(
                        baseStyle: Style(
                            borderColor: .blue.withAlphaComponent(0.5),
                            cornerRadius: 10,
                            padding: UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16),
                            borderWidth: 1.5,
                            font: .systemFont(ofSize: 18),
                            textColor: .darkText,
                            backgroundColor: .white.withAlphaComponent(0.95),
                            minWidth: nil,
                            maxWidth: nil,
                            width: nil,
                            placeholderColor: .gray.withAlphaComponent(0.4)
                        ),
                        focusStyle: Style(
                            borderColor: .blue,
                            borderWidth: 2,
                            backgroundColor: .white
                        ),
                        labelStyle: Style(
                            font: .systemFont(ofSize: 16, weight: .semibold),
                            textColor: .black
                        ),
                        completedStyle: Style(
                            borderColor: .green,
                            backgroundColor: .green.withAlphaComponent(0.05)
                        ),
                        invalidStyle: Style(
                            borderColor: .red,
                            backgroundColor: .red.withAlphaComponent(0.05)
                        )
                    )
                )
            ]
        )
        
        let cardForm = Payrails.CardForm(
            // TODO if config is passed extend default config
            config: defaultCardFormConfig,
            tableName: "tableName",
            cseConfig: (data: "", version: ""),
            holderReference: session.getSDKConfiguration()!.holderRefecerence,
            cseInstance: session.getCSEInstance()!
        )
        
        return cardForm
    }
    
    static func createCardPaymentForm(
        config: CardFormConfig = CardFormConfig(showNameField: false, fieldConfigs: []),
        buttonTitle: String = "Pay Now"
    ) -> Payrails.CardPaymentForm {
        
        precondition(currentSession != nil, "Payrails session must be initialized before creating a CardPaymentForm")
        
        let session = currentSession!
        
        let defaultCardFormConfig = CardFormConfig(
            showNameField: false,
            fieldConfigs: [
                CardFieldConfig(
                    type: .CARD_NUMBER,
                    placeholder: "1234 5678 9012 3456",
                    title: "Card Number",
                    style: CardFormStyle(
                        baseStyle: Style(
                            borderColor: .red.withAlphaComponent(0.5),
                            cornerRadius: 10,
                            padding: UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16),
                            borderWidth: 1.5,
                            font: .systemFont(ofSize: 18),
                            textColor: .darkText,
                            backgroundColor: .white.withAlphaComponent(0.95),
                            minWidth: nil,
                            maxWidth: nil,
                            width: nil,
                            placeholderColor: .gray.withAlphaComponent(0.4)
                        ),
                        focusStyle: Style(
                            borderColor: .blue,
                            borderWidth: 2,
                            backgroundColor: .white
                        ),
                        labelStyle: Style(
                            font: .systemFont(ofSize: 16, weight: .semibold),
                            textColor: .black
                        ),
                        completedStyle: Style(
                            borderColor: .green,
                            backgroundColor: .green.withAlphaComponent(0.05)
                        ),
                        invalidStyle: Style(
                            borderColor: .red,
                            backgroundColor: .red.withAlphaComponent(0.05)
                        )
                    )
                )
            ]
        )
        
        // Create the combined CardPaymentForm
        let cardPaymentForm = Payrails.CardPaymentForm(
            config: defaultCardFormConfig,
            tableName: "tableName",
            cseConfig: (data: "", version: ""),
            holderReference: session.getSDKConfiguration()!.holderRefecerence,
            cseInstance: session.getCSEInstance()!,
            session: session,
            buttonTitle: buttonTitle
        )
        
        return cardPaymentForm
    }
}

public extension Payrails {
    struct Debug {
        public static func configViewer(session: Payrails.Session) -> some View {
            SimplePayrailsViewer(config: session.debugConfig)
        }
    }
}
