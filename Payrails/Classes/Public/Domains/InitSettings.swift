//
//  InitSettings.swift
//  Pods
//
//  Created by Mustafa Dikici on 04.03.25.
//
import Foundation

public extension Payrails {

    struct InitSettings: Codable {
        init(
            amount: String,
            merchantReference: String,
            holderReference: String,
            type: String = "dropIn",
            workflowCode: String = "payment-acceptance"
        ) {
            self.holderReference = holderReference
            self.merchantReference = merchantReference
            self.type = type
            self.workflowCode = workflowCode
            self.amount = .init(
                value: amount,
                currency: "USD"
            )
            let address = DeliveryAddress(
                city: "Berlin",
                country: .init(code: "DE"),
                postalCode: "10405",
                street: "Straßburger Straße",
                doorNumber: "1"
            )
            self.meta = .init(
                order: .init(
                    reference: merchantReference,
                    deliveryAddress: address,
                    billingAddress: address
                ),
                billingAddress: address,
                customer: .init(
                    reference: holderReference,
                    country: ["code": "DE"]
                ),
                clientContext: .init(osType: "ios"),
                allowNative3DS: false
            )
        }

        let merchantReference: String
        let holderReference: String
        let type: String
        let meta: Meta
        let workflowCode: String
        let amount: Amount
    }

    struct Meta: Codable {
        let order: Order
        let billingAddress: DeliveryAddress
        let customer: Customer
        let clientContext: ClientContext
        let allowNative3DS: Bool
    }

    struct Amount: Codable {
        let value: String
        let currency: String
    }

    struct Order: Codable {
        let reference: String
        let deliveryAddress: DeliveryAddress
        let billingAddress: DeliveryAddress
    }

    struct Customer: Codable {
        let reference: String
        let country: [String: String]
    }

    struct ClientContext: Codable {
        let osType: String
    }

    struct DeliveryAddress: Codable {
        let city: String
        let country: Country
        let postalCode: String
        let street: String
        let doorNumber: String

        struct Country: Codable  {
            let code: String
        }
    }

    
}
