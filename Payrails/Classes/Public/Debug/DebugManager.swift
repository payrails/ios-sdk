import UIKit

public extension Payrails {

    public class DebugManager {
        
        public static let shared = DebugManager()
        private var logView: LogView?
        private var currentWindow: UIWindow? {
            // Try to get the active window
            if #available(iOS 13.0, *) {
                return UIApplication.shared.connectedScenes
                    .filter { $0.activationState == .foregroundActive }
                    .compactMap { $0 as? UIWindowScene }
                    .first?.windows
                    .first { $0.isKeyWindow }
            } else {
                return UIApplication.shared.keyWindow
            }
        }

        private init() {} // Singleton

        public func toggleLogView() {
            DispatchQueue.main.async {
                if self.logView?.superview != nil {
                    self.hideLogView()
                } else {
                    self.showLogView()
                }
            }
        }

        public func showLogView() {
            DispatchQueue.main.async {
                guard self.logView == nil || self.logView?.superview == nil else { return } // Already showing or instance exists without superview
                
                guard let window = self.currentWindow else {
                    print("Payrails.DebugManager Error: Could not find key window to present LogView.")
                    return
                }

                if self.logView == nil {
                    // Define a frame for the log view, e.g., bottom half of the screen
                    let windowBounds = window.bounds
                    let logViewHeight = windowBounds.height * 0.6
                    let logViewWidth = windowBounds.width * 0.9
                    let logViewX = (windowBounds.width - logViewWidth) / 2
                    let logViewY = windowBounds.height - logViewHeight - 40 // 40 points from bottom
                    
                    self.logView = LogView(frame: CGRect(x: logViewX, y: logViewY, width: logViewWidth, height: logViewHeight))
                }
                
                guard let logView = self.logView else { return }

                // Ensure it's brought to the front if it was somehow added but not visible
                window.addSubview(logView)
                window.bringSubviewToFront(logView)
                logView.isHidden = false // Ensure it's not hidden
            }
        }

        public func hideLogView() {
            DispatchQueue.main.async {
                self.logView?.isHidden = true // Hide it first
                self.logView?.removeFromSuperview()
                // self.logView = nil // Optionally nil out to recreate frame on next show, or keep instance
            }
        }
    }
}
