import Foundation

public enum PayrailsError: Error, LocalizedError {
    case authenticationError
    case sdkNotInitialized
    case missingData(String?)
    case invalidDataFormat
    case invalidCardData(error: Error?)
    case unknown(error: Error?)
    case unsupportedPayment(type: Payrails.PaymentType)
    case incorrectPaymentSetup(type: Payrails.PaymentType)
}

public extension PayrailsError {
    var errorDescription: String? {
        switch self {
        case .authenticationError:
            return "Authentication error: Token has expired"
        case .sdkNotInitialized:
            return "Payrails SDK has not been properly initialized"
        case .invalidDataFormat:
            return "Provided Config data is invalid and can not be parsed"
        case .invalidCardData(let error):
            return error?.localizedDescription ?? "Invalid Card Data provided"
        case .unknown(let error):
            return error?.localizedDescription ?? "Unknown error appeared"
        case let.missingData(missingData):
            return String(
                format: "SDK Configuration is missing field: %@",
                missingData ?? "unknown field"
            )
        case .unsupportedPayment(type: let type):
            return String(
                format: "Payrails SDK version does not yet support %@",
                type.rawValue
            )
        case .incorrectPaymentSetup(type: let type):
            return String(
                format: "Payrails SDK does not find proper configuration for payment %@",
                type.rawValue
            )
        }
    }
}
