//
//  SettingsDetailViews.swift
//  REPS
//
//  Created by Aaron Hill on 11/7/25.
//

import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

struct UnitsSettingsView: View {
    @State private var selection: Units = .lbs

    var body: some View {
        Form {
            Section("Measurement Units") {
                Picker("Default weight units", selection: $selection) {
                    ForEach(Units.allCases) { unit in
                        Text(unit.rawValue.uppercased()).tag(unit)
                    }
                }
                .pickerStyle(.segmented)

                Text("This choice applies across workouts, logging, and progress summaries.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Match device locale") {
                    matchDeviceLocale()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                AtlasNavigationTitle(title: "Units", subtitle: "Choose your defaults")
            }
        }
        .atlasNavigationBarStyle()
        .onAppear {
            selection = UserProfileStore.load()?.units ?? .lbs
        }
        .onChange(of: selection) { _, newValue in
            UserProfileStore.upsert { $0.units = newValue }
        }
    }

    private func matchDeviceLocale() {
        let usesMetric = Locale.current.usesMetricSystem
        selection = usesMetric ? .kgs : .lbs
    }
}

struct NotificationSettingsView: View {
    @State private var wantsReminders = false
    @State private var reminderTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    @State private var daysPerWeek: Int = 3
    @State private var statusDescription: String = ""
    @State private var showDeniedAlert = false

    var body: some View {
        Form {
            Section("Workout Reminders") {
                Toggle("Enable reminders", isOn: $wantsReminders)
                DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .disabled(!wantsReminders)

                Text(statusDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                Button("Open system Settings") {
                    openSystemSettings()
                }
                .disabled(statusDescription == "Notifications authorized")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                AtlasNavigationTitle(title: "Notifications", subtitle: "Stay on schedule")
            }
        }
        .atlasNavigationBarStyle()
        .onAppear(perform: loadState)
        .onChange(of: wantsReminders) { _, newValue in
            handleReminderToggle(newValue)
        }
        .onChange(of: reminderTime) { _, _ in
            guard wantsReminders else { return }
            scheduleReminders()
            persistReminderState()
        }
        .alert("Enable Notifications", isPresented: $showDeniedAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") { openSystemSettings() }
        } message: {
            Text("Notifications are turned off for REPS. Enable them in Settings to receive workout reminders.")
        }
    }

    private func loadState() {
        if let profile = UserProfileStore.load() {
            if let time = profile.reminderTime {
                wantsReminders = true
                reminderTime = time
            }
            daysPerWeek = profile.daysPerWeek
        }

        NotificationManager.shared.authStatus { status in
            DispatchQueue.main.async {
                statusDescription = description(for: status)
            }
        }
    }

    private func handleReminderToggle(_ enabled: Bool) {
        if enabled {
            NotificationManager.shared.authStatus { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        scheduleReminders()
                        persistReminderState()
                        statusDescription = description(for: status)
                    case .notDetermined:
                        NotificationManager.shared.requestAuthorization { granted in
                            DispatchQueue.main.async {
                                if granted {
                                    scheduleReminders()
                                    persistReminderState()
                                    statusDescription = description(for: .authorized)
                                } else {
                                    wantsReminders = false
                                    statusDescription = "Notifications not enabled"
                                }
                            }
                        }
                    case .denied:
                        wantsReminders = false
                        showDeniedAlert = true
                        statusDescription = description(for: status)
                    }
                }
            }
        } else {
            NotificationManager.shared.cancelReminders()
            persistReminderState()
            statusDescription = "Notifications off"
        }
    }

    private func scheduleReminders() {
        NotificationManager.shared.scheduleFromPlan(time: reminderTime, fallbackGoal: daysPerWeek)
    }

    private func persistReminderState() {
        UserProfileStore.upsert { profile in
            profile.reminderTime = wantsReminders ? reminderTime : nil
        }
    }

    private func description(for status: NotificationAuthStatus) -> String {
        switch status {
        case .authorized: return "Notifications authorized"
        case .notDetermined: return "Permission not requested"
        case .denied: return "Notifications denied"
        }
    }

    private func openSystemSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

struct IntegrationsSettingsView: View {
    @AppStorage("appleHealthEnabled") private var isConnected = false

    var body: some View {
        Form {
            Section("Apple Health") {
                Toggle("Share workouts to Health", isOn: $isConnected)
                    .disabled(true)

                Text("Health syncing is coming soon. We’ll notify you once it’s available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Why connect?") {
                Label("Sync completed workouts automatically", systemImage: "checkmark")
                Label("Close your activity rings faster", systemImage: "flame")
                Label("Keep health data in one place", systemImage: "heart")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                AtlasNavigationTitle(title: "Apple Health", subtitle: "Integrations")
            }
        }
        .atlasNavigationBarStyle()
    }
}

struct SupportSettingsView: View {
    var body: some View {
        Form {
            Section("Get help") {
                Label("View quick start guide", systemImage: "book")
                Label("Browse FAQs", systemImage: "questionmark.circle")
            }

            Section("Contact us") {
                Label("support@reps.app", systemImage: "envelope")
                Label("@repsapp", systemImage: "paperplane")
            }

            Section("Feedback") {
                Text("We’re building REPS with athletes like you. Share what’s working and what’s missing so we can improve the experience.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                AtlasNavigationTitle(title: "Help & Feedback", subtitle: "We’re here to help")
            }
        }
        .atlasNavigationBarStyle()
    }
}
