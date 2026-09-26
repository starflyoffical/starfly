import Foundation
import UserNotifications

@MainActor
final class RouteNotificationManager: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    private static let foregroundDelegate = RouteNotificationManager()
    private var authorizationTask: Task<Bool, Never>?

    static func configure() {
        UNUserNotificationCenter.current().delegate = foregroundDelegate
    }

    static func post(title: String, body: String) async {
        guard await foregroundDelegate.requestPermissionIfNeeded() else { return }
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "starfly.route.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    private func requestPermissionIfNeeded() async -> Bool {
        if let authorizationTask {
            return await authorizationTask.value
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            let task = Task {
                (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            }
            authorizationTask = task
            let isAuthorized = await task.value
            authorizationTask = nil
            return isAuthorized
        @unknown default:
            return false
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
