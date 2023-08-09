import Foundation

public class Payrails {

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
            let payrailsError = PayrailsError.unknown(error: error)
            onInit(.failure(payrailsError))
        }
    }

    @available(iOS 13.0.0, *)
    public static func configure(
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
}
