import Foundation
import UIKit
import UserNotifications
import Combine

/// Manages APNS registration and surfaces device-token / notification-tap events
/// to the rest of the app via Combine publishers.
@MainActor
final class NotificationService: ObservableObject {

    // Emits the hex device token string once registration succeeds.
    let deviceTokenPublisher = PassthroughSubject<String, Never>()

    // Emits the raw userInfo dict when the user taps a push notification.
    let notificationTapPublisher = PassthroughSubject<[AnyHashable: Any], Never>()

    // MARK: - Registration

    func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                guard granted else { return }
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
    }

    // MARK: - AppDelegate callbacks (called from AppDelegate)

    nonisolated func handleDeviceToken(_ data: Data) {
        let hex = data.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            self.deviceTokenPublisher.send(hex)
        }
    }

    nonisolated func handleNotificationTap(_ userInfo: [AnyHashable: Any]) {
        // AppDelegate callbacks are guaranteed on the main thread —
        // assumeIsolated avoids crossing an actor boundary with a non-Sendable type.
        MainActor.assumeIsolated {
            notificationTapPublisher.send(userInfo)
        }
    }
}
