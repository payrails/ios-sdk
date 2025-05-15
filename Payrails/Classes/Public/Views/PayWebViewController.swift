//
//  PayWebViewController.swift
//  Pods
//
//  Created by Mustafa Dikici on 15.05.25.
//
import WebKit

internal class PayWebViewController: UIViewController {

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
