import Foundation

public enum PayrailsError: Error, LocalizedError {
    case sdkNotInitialized
    case invalidDataFormat
    case unknown(error: Error)
    case unsupportedPayment(type: Payrails.PaymentType)
    case incorrectPaymentSetup(type: Payrails.PaymentType)
}

public extension PayrailsError {
    var errorDescription: String? {
        switch self {
        case .sdkNotInitialized:
            return "Payrails SDK has not been properly initialized"
        case .invalidDataFormat:
            return "Provided Config data is invalid and can not be parsed"
        case .unknown(let error):
            return error.localizedDescription
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
