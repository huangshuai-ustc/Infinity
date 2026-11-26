import Combine
import Foundation
import UserNotifications

struct InfinityReminder: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var fireDate: Date
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, fireDate: Date, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.fireDate = fireDate
        self.isCompleted = isCompleted
    }
}

@MainActor
final class ReminderStore: ObservableObject {
    static let shared = ReminderStore()

    @Published private(set) var reminders: [InfinityReminder] = []
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let defaults: UserDefaults
    private let storageKey = "infinity-reminders-v1"
    private let notifications = UNUserNotificationCenter.current()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        refreshAuthorizationStatus()
    }

    func requestNotificationPermission() async {
        do {
            _ = try await notifications.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            AppLogger.error("提醒通知权限申请失败：\(error.localizedDescription)")
        }
        refreshAuthorizationStatus()
    }

    func add(title: String, fireDate: Date) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, fireDate > Date() else { return }
        let reminder = InfinityReminder(title: trimmed, fireDate: fireDate)
        reminders.append(reminder)
        reminders.sort { $0.fireDate < $1.fireDate }
        save()

        let content = UNMutableNotificationContent()
        content.title = "Infinity"
        content.body = trimmed
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        do {
            try await notifications.add(request)
        } catch {
            AppLogger.error("提醒通知安排失败：\(error.localizedDescription)")
        }
    }

    func toggle(_ reminder: InfinityReminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index].isCompleted.toggle()
        save()
        if reminders[index].isCompleted {
            notifications.removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        }
    }

    func remove(_ reminder: InfinityReminder) {
        reminders.removeAll { $0.id == reminder.id }
        notifications.removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([InfinityReminder].self, from: data) else { return }
        reminders = decoded.sorted { $0.fireDate < $1.fireDate }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func refreshAuthorizationStatus() {
        notifications.getNotificationSettings { [weak self] settings in
            let status = settings.authorizationStatus
            Task { @MainActor in self?.authorizationStatus = status }
        }
    }
}
