import Foundation
import UserNotifications

/// Local notifications before a document expires. Nothing leaves the device.
enum ExpiryReminders {
    static let offsets = [90, 30, 7, 0]

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func schedule(uid: UUID, title: String, personName: String, expiry: Date?) {
        cancel(uid: uid)
        guard let expiry, !LaunchOptions.isDemo else { return }
        let center = UNUserNotificationCenter.current()
        let cal = Calendar.current
        for days in offsets {
            guard let day = cal.date(byAdding: .day, value: -days, to: expiry),
                  day > .now else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: day)
            comps.hour = 9
            let content = UNMutableNotificationContent()
            content.title = days == 0 ? tr("%@ expires today", title) : tr("%@ expires in %@", title, L10n.days(days))
            content.body = tr("%1$@'s %2$@ needs renewing.", personName, Localizer.shared.isArabic ? title : title.lowercased())
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "\(uid.uuidString)-\(days)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
            center.add(request)
        }
    }

    static func cancel(uid: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: offsets.map { "\(uid.uuidString)-\($0)" })
    }
}
