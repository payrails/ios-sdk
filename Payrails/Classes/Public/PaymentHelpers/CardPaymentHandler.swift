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
        let dictionary = ((response as? [String: Any])?["records"] as? [Any])?.first as? [String: Any]
        guard let fields = dictionary?["fields"] as? [String: Any] else {
            delegate?.paymentHandlerDidFail(handler: self, error: .missingData("fields"), type: .card)
            return
        }

        var data: [String: Any] = [:]
        data["vaultToken"] = fields["skyflow_id"]
        data["card"] = [
            "numberToken": fields["card_number"],
            "securityCodeToken": fields["security_code"]
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
        print(navigationAction)
        if let url = navigationAction.request.mainDocumentURL?.absoluteString {

            if url.hasPrefix("https://www.bootstrap.payrails.io/success") {
                decisionHandler(.cancel)
                delegate?.paymentHandlerDidHandlePending(
                    handler: self,
                    type: .card,
                    link: nil,
                    payload: [:]
                )
                webViewController?.dismiss(animated: true)
                webViewController = nil
                return
            } else if url.hasPrefix("https://www.bootstrap.payrails.io/cancel") {
                decisionHandler(.cancel)
                delegate?.paymentHandlerDidFinish(
                    handler: self,
                    type: .card,
                    status: .canceled,
                    payload: nil
                )
                webViewController?.dismiss(animated: true)
                webViewController = nil
                return
            } else if url.hasPrefix("https://www.bootstrap.payrails.io/error") {
                decisionHandler(.cancel)
                delegate?.paymentHandlerDidFinish(
                    handler: self,
                    type: .card,
                    status: .error(nil),
                    payload: nil
                )
                webViewController?.dismiss(animated: true)
                webViewController = nil
                return
            }

        }

        decisionHandler(.allow)
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
