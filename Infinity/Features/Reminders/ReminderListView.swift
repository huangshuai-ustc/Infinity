import SwiftUI
import UserNotifications

struct ReminderListView: View {
    @StateObject private var store = ReminderStore.shared
    @State private var isPresentingEditor = false

    var body: some View {
        Group {
            if store.reminders.isEmpty {
                Color.clear
                    .ignoresSafeArea()
            } else {
                List {
                    ForEach(store.reminders) { reminder in
                        ReminderRow(reminder: reminder) {
                            store.toggle(reminder)
                        } onDelete: {
                            store.remove(reminder)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("添加提醒")
            }
        }
        .task {
            if store.authorizationStatus == .notDetermined {
                await store.requestNotificationPermission()
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            ReminderEditor(store: store)
        }
    }
}

private struct ReminderRow: View {
    let reminder: InfinityReminder
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(reminder.isCompleted ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                Text(reminder.fireDate, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .swipeActions {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

private struct ReminderEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ReminderStore
    @State private var title = ""
    @State private var fireDate = Date().addingTimeInterval(3600)

    var body: some View {
        NavigationStack {
            Form {
                Section("提醒内容") {
                    TextField("例如：给猫咪补水", text: $title)
                        .textInputAutocapitalization(.sentences)
                }
                Section("提醒时间") {
                    DatePicker("时间", selection: $fireDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("新建提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        Task {
                            await store.add(title: title, fireDate: fireDate)
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
