import Foundation
import SwiftUICore
import UIKit

public class Payrails {
    // Keep existing code
    public static func configure(
        with configuration: Payrails.Configuration,
        onInit: OnInitCallback
    ) {
        do {
            let payrailsSession = try Payrails.Session(
                configuration
            )
            onInit(.success(payrailsSession))
        } catch {
            onInit(
                .failure(
                    PayrailsError.unknown(error: error)
                )
            )
        }
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
        session: Payrails.Session,
        config: CardFormConfig,
        cseConfig: (data: String, version: String),
        holderReference: String
    ) -> Payrails.CardForm {
        
        let cardForm = Payrails.CardForm(
            config: config,
            tableName: "tableName",
            cseConfig: (data: "", version: ""),  // Placeholder values
            holderReference: holderReference,
            cseInstance: session.getCSEInstance()!
        )
        
        // Set the CSE instance directly from the session
//        cardForm.payrailsCSE = session.payrailsCSE
        
        return cardForm
    }
}

public extension Payrails {
    struct Debug {
        public static func configViewer(session: Payrails.Session) -> some View {
            SimplePayrailsViewer(config: session.debugConfig)
        }
    }
}
