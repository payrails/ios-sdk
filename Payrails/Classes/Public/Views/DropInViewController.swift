import Foundation
import UIKit

final public class DropInViewController: UIViewController, PaymentPresenter {
    public func presentPayment(_ viewController: UIViewController) {
        present(viewController, animated: true)
    }
    

    private let configuration: Payrails.Configuration
    private var dropInView: DropInView!
    private let session: Payrails.Session

    public var callback: OnPayCallback?

    public init(
        configuration: Payrails.Configuration
    ) throws {
        session = try Payrails.Session(configuration)
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
        if let dropInView = session.buildDropInView(
            presenter: self,
            onResult: onPayCallback
        ) {
            self.dropInView = dropInView
        } else {
            throw PayrailsError.sdkNotInitialized
        }
    }

    private lazy var onPayCallback: OnPayCallback = { [weak self] result in
        self?.callback?(result)
    }

    required init?(coder: NSCoder) { nil }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(dropInView)
        dropInView.backgroundColor = .white
        dropInView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(
            [
                dropInView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                dropInView.topAnchor.constraint(equalTo: view.topAnchor),
                dropInView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                dropInView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ]
        )
    }
}
