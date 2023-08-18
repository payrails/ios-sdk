import Foundation

public typealias OnInitCallback = ((Result<Payrails.Session, PayrailsError>) -> Void)
public typealias OnPayCallback = ((OnPayResult) -> Void)

public struct OnInitData {
    public let executionId: String
    public let session: Payrails
}

public enum OnPayResult {
    case success, authorizationFailed, failure, error(PayrailsError), cancelledByUser
}
