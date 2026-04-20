import Foundation
import UserNotifications

public protocol NotificationServiceProtocol {
    func requestPermission()
    func notifyPortDown(port: Int, projectName: String?)
}

public class NotificationService: NotificationServiceProtocol {
    /// Shared instance for permission requests (e.g. from Settings) so we don’t allocate per toggle.
    public static let shared = NotificationService()

    private var center: UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }

    public init() {}

    public func requestPermission() {
        center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func notifyPortDown(port: Int, projectName: String?) {
        guard let center else { return }

        let content = UNMutableNotificationContent()
        content.title = "Port \(port) stopped"
        if let name = projectName {
            content.body = "\(name) on port \(port) is no longer listening."
        } else {
            content.body = "Port \(port) is no longer listening."
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "port-down-\(port)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}
