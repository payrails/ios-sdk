import UIKit

public extension Payrails {
    enum PaymentType: String, Decodable {
        case payPal, applePay
    }
}
