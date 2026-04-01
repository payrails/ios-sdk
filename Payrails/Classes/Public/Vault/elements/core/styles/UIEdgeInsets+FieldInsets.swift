import UIKit

public extension UIEdgeInsets {
    /// Creates field insets with defaults of (top: 0, left: 16, bottom: 0, right: 16).
    /// Only override the sides you need.
    static func fieldInsets(
        top: CGFloat = 0,
        left: CGFloat = 16,
        bottom: CGFloat = 0,
        right: CGFloat = 16
    ) -> UIEdgeInsets {
        UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
    }
}
