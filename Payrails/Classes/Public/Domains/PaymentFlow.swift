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

public enum InstrumentAPIResponse {
    case delete(DeleteInstrumentResponse)
    case update(UpdateInstrumentResponse)
}
