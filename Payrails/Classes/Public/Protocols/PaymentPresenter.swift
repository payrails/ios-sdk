import Foundation
import UIKit

public protocol PaymentPresenter: AnyObject {
    func presentPayment(_ viewController: UIViewController)
}
