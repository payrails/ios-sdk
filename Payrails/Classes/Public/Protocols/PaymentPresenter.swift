import Foundation
import UIKit

public protocol PaymentPresenter: AnyObject {
    func presentPayment(_ viewController: UIViewController)
    var encryptedCardData: String? { get set }
}
