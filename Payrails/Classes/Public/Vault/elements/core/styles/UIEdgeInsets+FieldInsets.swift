import UIKit

public extension UIEdgeInsets {
    /// Creates field insets with defaults of (top: 0, left: 6, bottom: 0, right: 6).
    /// Only override the sides you need.
    static func fieldInsets(
        top: CGFloat = 0,
        left: CGFloat = 6,
        bottom: CGFloat = 0,
        right: CGFloat = 6
    ) -> UIEdgeInsets {
        UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
    }
}
