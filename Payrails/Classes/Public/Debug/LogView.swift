import UIKit

public extension Payrails {

    internal class LogView: UIView {

        private let textView = UITextView()
        private let closeButton = UIButton(type: .system)
        private let clearButton = UIButton(type: .system)
        private let titleLabel = UILabel()

        override init(frame: CGRect) {
            super.init(frame: frame)
            setupView()
            observeLogUpdates()
            updateLogs()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupView()
            observeLogUpdates()
            updateLogs()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        private func setupView() {
            backgroundColor = UIColor(white: 0.1, alpha: 0.85)
            layer.cornerRadius = 10
            layer.masksToBounds = true
            
            // Title Label
            titleLabel.text = "Payrails SDK Logs"
            titleLabel.textColor = .white
            titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
            titleLabel.textAlignment = .center
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            addSubview(titleLabel)

            // Close Button
            closeButton.setTitle("Close", for: .normal)
            closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            closeButton.setTitleColor(.white, for: .normal)
            closeButton.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
            closeButton.layer.cornerRadius = 5
            addSubview(closeButton)

            // Clear Button
            clearButton.setTitle("Clear", for: .normal)
            clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
            clearButton.translatesAutoresizingMaskIntoConstraints = false
            clearButton.setTitleColor(.white, for: .normal)
            clearButton.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
            clearButton.layer.cornerRadius = 5
            addSubview(clearButton)
            
            // TextView
            textView.isEditable = false
            textView.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
            textView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
            textView.textColor = .green // Classic console green
            textView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(textView)

            // Layout
            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
                titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
                titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

                closeButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
                closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                closeButton.widthAnchor.constraint(equalToConstant: 60),
                
                clearButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
                clearButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
                clearButton.widthAnchor.constraint(equalToConstant: 60),

                textView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 8),
                textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
                textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
            ])
        }

        private func observeLogUpdates() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(updateLogs),
                name: LogStore.didUpdateLogNotification,
                object: nil
            )
        }

        @objc private func updateLogs() {
            DispatchQueue.main.async {
                let logs = LogStore.shared.getLogs()
                self.textView.text = logs.joined(separator: "\n")
                // Scroll to bottom
                if !logs.isEmpty {
                    let range = NSRange(location: self.textView.text.count - 1, length: 1)
                    self.textView.scrollRangeToVisible(range)
                }
            }
        }

        @objc private func closeTapped() {
            DebugManager.shared.hideLogView()
        }

        @objc private func clearTapped() {
            LogStore.shared.clearLogs()
            // updateLogs will be called via notification
        }
    }
}
