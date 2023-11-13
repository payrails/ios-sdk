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
    private var cardContainer: CardContainer?
    private let payrailsConfig: SDKConfig
    fileprivate var delegate: CardSessionDelegate?

    init(
        vaultId: String,
        vaultUrl: String,
        token: String,
        tableName: String,
        config payrailsConfig: SDKConfig,
        delegate: CardSessionDelegate?
    ) {
        config = Skyflow.Configuration(
            vaultID: vaultId,
            vaultURL: vaultUrl,
            tokenProvider: PayrailsTokenProvider(token: token),
            options: Skyflow.Options(
                logLevel: Skyflow.LogLevel.ERROR
            )
        )
        self.skyflow = Skyflow.initialize(config)
        self.tableName = tableName
        self.payrailsConfig = payrailsConfig
        self.delegate = delegate
    }

    func buildCardView(
        with config: CardFormConfig
    ) -> UIView? {
        let view = CardCollectView(
            skyflow: skyflow,
            config: config,
            tableName: tableName
        )
        self.cardContainer = view.cardContainer
        return view
    }

    func buildCardFields(
        with config: CardFormConfig
    ) -> [CardField]? {
        let elementsGenerater = CardFormElementsGenerator(
            skyflow: skyflow,
            config: config,
            tableName: tableName
        )
        self.cardContainer = elementsGenerater?.cardElemenetsContainer
        return elementsGenerater?.buildCardFields() ?? []
    }

    func buildDropInView(
        with formConfig: CardFormConfig = CardFormConfig.defaultConfig,
        session: Payrails.Session,
        onPay: @escaping ((DropInPaymentType) -> Void)
    ) -> DropInView? {
        DropInView(
            with: payrailsConfig,
            session: session,
            formConfig: formConfig,
            onPay: onPay
        )
    }

    @MainActor
    func collect() {
        cardContainer?.collect(with: self)
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

extension CardSession: Skyflow.Callback {

    func onSuccess(_ responseBody: Any) {
        delegate?.cardSessionConfirmed(with: responseBody)
    }

    func onFailure(_ error: Any) {
        delegate?.cardSessionFailed(with: error)
    }
}
