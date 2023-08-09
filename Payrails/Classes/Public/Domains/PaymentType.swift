import UIKit

public extension Payrails {
    enum PaymentType: String, Decodable {
        case card, payPal, applePay, other
    }
}
