import Foundation

struct AuthorizeResponse: Decodable {
    let name: String
    let actionId: String
    let links: AuthorizeLinks
    let executedAt: Date
}

struct AuthorizeLinks: Decodable {
  let execution: String?
  let consumerWait: String?
}

struct GetExecutionResult: Decodable {
    let id: String
    let status: [Status]
    var sortedStatus: [Status] {
        status.sorted { $0.time > $1.time }
    }
    let createdAt: Date
    let merchantReference: String
    let holderReference: String
    let workflow: Workflow
    let links: ExecutionLinks
    let actionRequired: String?
}

public struct DeleteInstrumentResponse: Decodable {
    public let success: Bool
}

public struct UpdateInstrumentBody: Encodable {
    public let status: String?
    public let networkTransactionReference: String?
    public let merchantReference: String?
    public let paymentMethod: String?
    public let `default`: Bool?

    public init(
        status: String? = nil,
        networkTransactionReference: String? = nil,
        merchantReference: String? = nil,
        paymentMethod: String? = nil,
        default: Bool? = nil
    ) {
        self.status = status
        self.networkTransactionReference = networkTransactionReference
        self.merchantReference = merchantReference
        self.paymentMethod = paymentMethod
        self.`default` = `default`
    }
}

public struct UpdateInstrumentResponse: Decodable {
    public let id: String
    public let createdAt: String
    public let holderId: String
    public let paymentMethod: String
    public let status: String
    public let data: InstrumentData
    public let fingerprint: String?
    public let futureUsage: String?

    public struct InstrumentData: Decodable {
        public let bin: String
        public let binLookup: BinLookup?
        public let holderName: String?
        public let network: String
        public let suffix: String
        public let expiryMonth: String?
        public let expiryYear: String?

        public struct BinLookup: Decodable {
            public let bin: String
            public let network: String
            public let issuer: String?
            public let issuerCountry: IssuerCountry?
            public let type: String?

            public struct IssuerCountry: Decodable {
                public let code: String?
                public let name: String?
                public let iso3: String?
            }
        }
    }
}

// MARK: - Tokenize / Save Instrument

public enum FutureUsage: String, Encodable {
    case cardOnFile = "CardOnFile"
    case subscription = "Subscription"
    case unscheduledCardOnFile = "UnscheduledCardOnFile"
}

public struct TokenizeOptions {
    public let storeInstrument: Bool
    public let futureUsage: FutureUsage

    public init(
        storeInstrument: Bool = false,
        futureUsage: FutureUsage = .cardOnFile
    ) {
        self.storeInstrument = storeInstrument
        self.futureUsage = futureUsage
    }
}

struct SaveInstrumentBody: Encodable {
    let holderReference: String
    let paymentMethod: String
    let storeInstrument: Bool
    let futureUsage: String
    let data: SaveInstrumentBodyData

    // Pin the wire keys explicitly so a Swift property rename can't silently change the
    // backend payload. These names are the create-instrument contract, not Swift conventions.
    enum CodingKeys: String, CodingKey {
        case holderReference
        case paymentMethod
        case storeInstrument
        case futureUsage
        case data
    }
}

/// Wire shape of the create-instrument `data` object. These keys are defined by the backend
/// (and mirror the web-sdk): a **card** sends `encryptedData` (vault ciphertext) + `vaultProviderConfigId`;
/// a **wallet** (Apple Pay) sends `paymentToken` (the stringified wallet payment). They're
/// per-method and mutually exclusive — the JSON encoder omits the unused (nil) fields.
struct SaveInstrumentBodyData: Encodable {
    var encryptedData: String?
    var vaultProviderConfigId: String?
    var paymentToken: String?

    // Construct only via the per-method factories below, so an empty or half-filled payload
    // can't be built by accident at a call site.
    private init(encryptedData: String? = nil, vaultProviderConfigId: String? = nil, paymentToken: String? = nil) {
        self.encryptedData = encryptedData
        self.vaultProviderConfigId = vaultProviderConfigId
        self.paymentToken = paymentToken
    }

    /// Card create-instrument payload: vault ciphertext + the provider config that produced it.
    static func card(encryptedData: String, vaultProviderConfigId: String) -> Self {
        .init(encryptedData: encryptedData, vaultProviderConfigId: vaultProviderConfigId)
    }

    /// Wallet (Apple Pay) create-instrument payload: the stringified wallet payment token.
    static func applePay(paymentToken: String) -> Self {
        .init(paymentToken: paymentToken)
    }

    // Backend-defined keys. `nil` fields are still omitted by JSONEncoder, so the card
    // (encryptedData + vaultProviderConfigId) and wallet (paymentToken) shapes stay mutually
    // exclusive — CodingKeys only pins the names, not which keys are emitted.
    enum CodingKeys: String, CodingKey {
        case encryptedData
        case vaultProviderConfigId
        case paymentToken
    }
}

public struct SaveInstrumentResponse: Decodable {
    public let id: String
    public let createdAt: String
    public let holderId: String
    public let paymentMethod: String
    public let status: String
    public let data: InstrumentData
    public let fingerprint: String?
    public let futureUsage: String?

    public struct InstrumentData: Decodable {
        public let bin: String?
        public let binLookup: BinLookup?
        public let holderName: String?
        public let network: String?
        public let suffix: String?
        public let expiryMonth: String?
        public let expiryYear: String?

        public struct BinLookup: Decodable {
            public let bin: String?
            public let network: String?
            public let issuer: String?
            public let issuerCountry: IssuerCountry?
            public let type: String?

            public struct IssuerCountry: Decodable {
                public let code: String?
                public let name: String?
                public let iso3: String?
            }
        }
    }
}
