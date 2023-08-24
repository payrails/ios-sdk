import Foundation

extension SDKConfig {
    func paymentOption(
        for type: Payrails.PaymentType,
        extra: ((PaymentCompositionOptions) -> Bool)? = nil
    ) -> PaymentCompositionOptions? {
        let initialResult = execution?.initialResults.first(where: {
            $0.body.name == "lookup" && $0.body.data.paymentCompositionOptions.first(where: {
                var result = $0.paymentType == type
                if let extra {
                    result = result && extra($0)
                }
                return result
            }) != nil
        })
        return initialResult?.body.data.paymentCompositionOptions.first(where: {
            $0.paymentType == type
        })
    }
}
