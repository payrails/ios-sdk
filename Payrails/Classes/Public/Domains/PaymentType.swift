import UIKit

public extension Payrails {
    enum PaymentType: String, Decodable {
        case payPal, applePay, card, genericRedirect
    }

    /// What the merchant hands to `Session.tokenize` to say *which* instrument to tokenize and
    /// *how*. One case per method, each carrying exactly what that method needs — so adding a
    /// new method later (e.g. PayPal) is a new case and `tokenize`'s signature never changes.
    ///
    /// Unlike `PaymentType` (a wire-decodable `String` enum), this holds live runtime objects
    /// (a presenter, the card form), so it is intentionally NOT `Decodable`.
    enum TokenizationRequest {
        /// Apple Pay: the SDK presents the PassKit sheet via `presenter`, then tokenizes the wallet token.
        case applePay(presenter: PaymentPresenter)

        /// Card: the SDK reads and encrypts the live fields from the merchant's embedded
        /// `CardForm` — no presenter needed, the form is already on screen.
        case card(CardForm)

        // Future methods slot in here with no change to `tokenize`'s signature, e.g.:
        // case payPal(presenter: PaymentPresenter)
    }
}
