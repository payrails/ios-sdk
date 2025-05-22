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
