import Foundation
import WebKit

class CardPaymentHandler: NSObject {

    private weak var delegate: PaymentHandlerDelegate?
    private var response: Any?
    private let saveInstrument: Bool
    private weak var presenter: PaymentPresenter?
    private var webViewController: PayWebViewController?

    init(
        delegate: PaymentHandlerDelegate?,
        saveInstrument: Bool,
        presenter: PaymentPresenter?
    ) {
        print("init card payment handler")
        self.delegate = delegate
        self.saveInstrument = saveInstrument
        self.presenter = presenter
    }
}

extension CardPaymentHandler: PaymentHandler {
    func set(response: Any) {
        self.response = response
    }
    
    func makePayment(
        total: Double,
        currency: String,
        presenter: PaymentPresenter?
    ) {
        let effectivePresenter = presenter ?? self.presenter
        
        guard let encryptedCardData = effectivePresenter?.encryptedCardData, !encryptedCardData.isEmpty else {
            print("Error: Missing or empty encrypted card data.")
            delegate?.paymentHandlerDidFail(
                handler: self,
                error: .missingData("Encrypted card data is required but was missing or empty."),
                type: .card
            )
            return
        }

        var data: [String: Any] = [:]
        data["card"] = [
//            TODO: this should come from config
            "vaultProviderConfigId": "0077318a-5dd2-47fb-b709-e475d2172d32",
            "encryptedData": encryptedCardData
        ]

        delegate?.paymentHandlerDidFinish(
            handler: self,
            type: .card,
            status: .success,
            payload: [
                "paymentInstrumentData": data,
                "storeInstrument": saveInstrument
            ]
        )
    }

    func handlePendingState(with executionResult: GetExecutionResult) {
        guard let link = executionResult.links.threeDS,
              let url = URL(string: link) else {
            delegate?.paymentHandlerDidFail(
                handler: self,
                error: .missingData("Pending state failed due to missing 3ds link"),
                type: .card
            )
            return
        }

        DispatchQueue.main.async {
            let webViewController = PayWebViewController(
                url: url,
                delegate: self
            )
            self.presenter?.presentPayment(webViewController)
            self.webViewController = webViewController
        }
    }
}

extension CardPaymentHandler: WKNavigationDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let urlString = navigationAction.request.mainDocumentURL?.absoluteString else {
            // If we can't get the URL string, allow navigation (or handle as error if needed)
            decisionHandler(.allow)
            return
        }

        let successPrefix = "https://assets.payrails.io/html/payrails-success.html"
        let cancelPrefix = "https://assets.payrails.io/html/payrails-cancel.html"
        let errorPrefix = "https://assets.payrails.io/html/payrails-error.html"

        let finalAction: (() -> Void)?

        if urlString.hasPrefix(successPrefix) {
            finalAction = { [weak self] in
                guard let self = self else { return }
                self.delegate?.paymentHandlerDidHandlePending(
                    handler: self,
                    type: .card,
                    link: nil,
                    payload: [:]
                )
            }
        } else if urlString.hasPrefix(cancelPrefix) {
            finalAction = { [weak self] in
                guard let self = self else { return }
                self.delegate?.paymentHandlerDidFinish(
                    handler: self,
                    type: .card,
                    status: .canceled,
                    payload: nil
                )
            }
        } else if urlString.hasPrefix(errorPrefix) {
            finalAction = { [weak self] in
                guard let self = self else { return }
                self.delegate?.paymentHandlerDidFinish(
                    handler: self,
                    type: .card,
                    status: .error(nil),
                    payload: nil
                )
            }
        } else {
            finalAction = nil
        }

        // If we matched one of the final URLs, perform the common cleanup and specific action
        if let action = finalAction {
            decisionHandler(.cancel)
            action()
            webViewController?.dismiss(animated: true)
            webViewController = nil
        } else {
            decisionHandler(.allow)
        }
    }
}

private class PayWebViewController: UIViewController {

    private var webView = WKWebView(frame: .zero)
    private let url: URL

    init(url: URL, delegate: WKNavigationDelegate) {
        self.url = url
        webView.navigationDelegate = delegate
        super.init(nibName: nil, bundle: nil)
     }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        webView.load(.init(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
    }
}

