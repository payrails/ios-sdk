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
    
    public struct CardInitResult {
        public let session: Payrails.Session
        public let initData: Payrails.InitData
    }
    
    public typealias CardInitCallback = (Result<CardInitResult, PayrailsError>) -> Void
    
    // A simpler method that just handles the session initialization and returns both
    // the session and the original init data
    public static func initializeCard(
        with configuration: Payrails.Configuration,
        onInit: @escaping CardInitCallback
    ) {
        do {
            let payrailsSession = try Payrails.Session(
                configuration
            )
            let result = CardInitResult(
                session: payrailsSession,
                initData: configuration.initData
            )
            onInit(.success(result))
        } catch {
            onInit(
                .failure(
                    PayrailsError.unknown(error: error)
                )
            )
        }
    }
    
    // Async/await version
    public static func initializeCard(
        with configuration: Payrails.Configuration
    ) async throws -> CardInitResult {
        let result = try await withCheckedThrowingContinuation { continuation in
            Payrails.initializeCard(with: configuration) { result in
                switch result {
                case .success(let initResult):
                    continuation.resume(returning: initResult)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        return result
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
}

public extension Payrails {
    struct Debug {
        public static func configViewer(session: Payrails.Session) -> some View {
            SimplePayrailsViewer(config: session.debugConfig)
        }
    }
}
