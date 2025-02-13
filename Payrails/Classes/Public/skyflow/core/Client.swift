/*
 * Copyright (c) 2022 Skyflow
*/

// Implementation of Skyflow Client class

import Foundation
import AEXML

public class Client {
    var vaultID: String
    var vaultURL: String
    var contextOptions: ContextOptions
    var elementLookup: [String: Any] = [:]
    
    public init() {
        self.vaultID = "xxxx"
        self.vaultURL = "vault.skyflow.io"
        self.contextOptions = ContextOptions(logLevel: LogLevel.DEBUG, env: Env.DEV, interface: .CLIENT)
        Log.info(message: .CLIENT_INITIALIZED, contextOptions: self.contextOptions)
    }

    public func container<T>(type: T.Type, options: ContainerOptions? = nil) -> Container<T>? {
        if options != nil {
            // Set options
        }

        if T.self == ComposableContainer.self {
            return Container<T>(skyflow: self, options: options)
        }
        return nil
    }

    public func getById(records: [String: Any], callback: Callback) {
        var tempContextOptions = self.contextOptions
        tempContextOptions.interface = .GETBYID
        Log.info(message: .GET_BY_ID_TRIGGERED, contextOptions: tempContextOptions)
        let errorCode = ErrorCodes.EMPTY_VAULT_ID()
        callback.onFailure(errorCode.getErrorObject(contextOptions: tempContextOptions))
    }

    

    private func callRevealOnFailure(callback: Callback, errorObject: Error) {
        let result = ["errors": [errorObject]]
        callback.onFailure(result)
    }
    
    internal func createDetokenizeRecords(_ IDsToTokens: [String: String]) -> [String: [[String: String]]]{
        var records = [] as [[String : String]]
        var index = 0
        for (_, token) in IDsToTokens {
            records.append(["token": token])
            index += 1
        }
        
        return ["records": records]
    }
}
