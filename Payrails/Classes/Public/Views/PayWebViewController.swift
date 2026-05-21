//
//  PayWebViewController.swift
//  Pods
//
//

import WebKit

internal class PayWebViewController: UIViewController {

    private var webView = WKWebView(frame: .zero)
    private let url: URL
    private let dismissalCallback: (() -> Void)?

    /// Fired when the user interactively dismisses this view (e.g. swipe-down on iOS 13+
    /// sheet presentation). NOT fired when the SDK dismisses the controller programmatically.
    var onUserDismiss: (() -> Void)?

    init(url: URL, delegate: WKNavigationDelegate, dismissalCallback: (() -> Void)? = nil) {
        self.url = url
        self.dismissalCallback = dismissalCallback
        webView.navigationDelegate = delegate
        super.init(nibName: nil, bundle: nil)
     }

    required init?(coder: NSCoder) { nil }

    deinit {
        dismissalCallback?()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Receive the system's user-initiated dismissal callback (swipe-down on sheet
        // presentations). Set here so we have a valid presentationController.
        presentationController?.delegate = self
    }
}

extension PayWebViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // UIKit only invokes this when the user dismissed the sheet (not when we did it
        // programmatically), so it is the right signal to surface as "user cancelled 3DS".
        onUserDismiss?()
    }
}
