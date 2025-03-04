import SwiftUI

internal struct SimplePayrailsViewer: View {
    let config: SDKConfig
    
    var body: some View {
        List {
            // Overview Section
            Section(header: Text("Overview")) {
 
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text("\(config.amount.value) \(config.amount.currency)")
                            .fontWeight(.medium)
                    }
                
                
                if let holderRef = config.holderReference {
                    HStack {
                        Text("Holder Reference")
                        Spacer()
                        Text(holderRef)
                            .fontWeight(.medium)
                    }
                }
                
                HStack {
                    Text("Token")
                    Spacer()
                    Text(String(config.token.prefix(15)) + "...")
                        .fontWeight(.medium)
                }
            }
            
            // Vault Section
            if let vault = config.vaultConfiguration {
                Section(header: Text("Vault Configuration")) {
                    if let status = vault.status {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(status)
                                .fontWeight(.medium)
                        }
                    }
                    
                    if let providerId = vault.providerId {
                        HStack {
                            Text("Provider ID")
                            Spacer()
                            Text(providerId)
                                .fontWeight(.medium)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            // Execution Section
            if let execution = config.execution {
                Section(header: Text("Execution")) {
                    HStack {
                        Text("ID")
                        Spacer()
                        Text(execution.id)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                    
                    HStack {
                        Text("Merchant Reference")
                        Spacer()
                        Text(execution.merchantReference)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        if let lastStatus = execution.status.last {
                            Text(lastStatus.code)
                                .fontWeight(.medium)
                                .foregroundColor(statusColor(for: lastStatus.code))
                        } else {
                            Text("Unknown")
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Workflow
                    HStack {
                        Text("Workflow")
                        Spacer()
                        Text("\(execution.workflow.code) v\(execution.workflow.version)")
                            .fontWeight(.medium)
                    }
                }
                
                // Payment Options Section
                if let firstResult = execution.initialResults.first {
                    Section(header: Text("Payment Options")) {
                        ForEach(firstResult.body.data.paymentOptions.indices, id: \.self) { index in
                            let option = firstResult.body.data.paymentOptions[index]
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(option.clientConfig?.displayName ?? option.paymentMethodCode)
                                        .font(.headline)
                                    Spacer()
                                    Text(option.integrationType)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let flow = option.clientConfig?.flow {
                                    Text("Flow: \(flow)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Payrails Data")
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "created", "new":
            return .blue
        case "pending", "processing":
            return .orange
        case "completed", "success":
            return .green
        case "failed", "error":
            return .red
        default:
            return .gray
        }
    }
}

// Usage:
// SimplePayrailsViewer(config: yourSDKConfig)
