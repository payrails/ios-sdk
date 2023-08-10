import Foundation

extension SDKConfig {
    func paymentComposition(for type: Payrails.PaymentType) -> PaymentCompositionOptions? {
        let initialResult = execution?.initialResults.first(where: {
            $0.body.data.paymentCompositionOptions.first(where: {
                $0.paymentType == type
            }) != nil
        })
        return initialResult?.body.data.paymentCompositionOptions.first(where: {
            $0.paymentType == type
        })
    }
}