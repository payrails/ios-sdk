import Foundation

public enum PayrailsError: Error, LocalizedError {
    case authenticationError
    case sdkNotInitialized
    case missingData(String?)
    case invalidDataFormat
    case invalidCardData
    case unknown(error: Error?)
    case unsupportedPayment(type: Payrails.PaymentType)
    case incorrectPaymentSetup(type: Payrails.PaymentType)

    case pollingFailed(String)
    case failedToDerivePaymentStatus(String)
    case finalStatusNotFoundAfterLongPoll(String)
    case longPollingFailed(underlyingError: Error?)
}

public extension PayrailsError {
    var errorDescription: String? {
        switch self {
        case .authenticationError:
            return "Authentication error: Token has expired or is invalid."
        case .sdkNotInitialized:
            return "Payrails SDK has not been properly initialized. Please call Payrails.initialize() first."
        case .invalidDataFormat:
            return "Provided configuration data is invalid and cannot be parsed."
        case .invalidCardData:
            return "Invalid card data provided."
        case .unknown(let error):
            if let underlyingError = error {
                return "An unknown error occurred: \(underlyingError.localizedDescription)"
            }
            return "An unknown error occurred."
        case .missingData(let missingData):
            return String(
                format: "SDK Configuration or required data is missing field: %@",
                missingData ?? "unknown field"
            )
        case .unsupportedPayment(type: let type):
            return String(
                format: "This version of the Payrails SDK does not support the payment type: %@",
                type.rawValue
            )
        case .incorrectPaymentSetup(type: let type):
            return String(
                format: "The Payrails SDK could not find a proper configuration for the payment type: %@",
                type.rawValue
            )
        case .pollingFailed(let reason):
            return "Payment status polling failed: \(reason)"
        case .failedToDerivePaymentStatus(let reason):
            return "Could not determine payment status: \(reason)"
        case .finalStatusNotFoundAfterLongPoll(let reason):
            return "Final payment status not found after polling: \(reason)"
        case .longPollingFailed(let underlyingError):
            if let error = underlyingError {
                return "Long polling for payment status failed: \(error.localizedDescription)"
            }
            return "Long polling for payment status failed due to an unknown issue."
        }
    }
}
