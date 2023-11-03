import Foundation
import Skyflow

protocol CardSessionDelegate: AnyObject {
    func cardSessionConfirmed(with response: Any)
    func cardSessionFailed(with error: Any)
}

class CardSession {

    private let config: Skyflow.Configuration
    private let skyflow: Skyflow.Client
    private let tableName: String
    private let submitCallback: SubmitCallback

    init(
        vaultId: String,
        vaultUrl: String,
        token: String,
        tableName: String,
        delegate: CardSessionDelegate?
    ) {
        config = Skyflow.Configuration(
            vaultID: vaultId,
            vaultURL: vaultUrl,
            tokenProvider: PayrailsTokenProvider(token: token),
            options: Skyflow.Options(
                logLevel: Skyflow.LogLevel.DEBUG
            )
        )
        self.skyflow = Skyflow.initialize(config)
        self.tableName = tableName
        self.submitCallback = .init(delegate: delegate)
    }

    func buildCardView(
        with config: CardFormConfig
    ) -> UIView? {
        CardCollectView(
            skyflow: skyflow,
            config: config,
            tableName: tableName,
            callback: submitCallback
        )
    }
}

private class PayrailsTokenProvider: TokenProvider {
    private let token: String

    init(token: String) {
        self.token = token
    }

    func getBearerToken(_ apiCallback: Skyflow.Callback) {
        apiCallback.onSuccess(token)
    }

}

private class SubmitCallback: Skyflow.Callback {

    private weak var delegate: CardSessionDelegate?

    init(delegate: CardSessionDelegate?) {
        self.delegate = delegate
    }

    func onSuccess(_ responseBody: Any) {
        delegate?.cardSessionConfirmed(with: responseBody)
    }

    func onFailure(_ error: Any) {
        delegate?.cardSessionFailed(with: error)
    }
}
