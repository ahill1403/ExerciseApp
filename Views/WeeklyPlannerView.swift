//
//  WeeklyPlannerView.swift
//  AtlasFit
//

import SwiftUI
import UserNotifications

struct WeeklyPlannerView: View {
    // 1=Sun … 7=Sat
    private let days: [(Int, String)] = [(1,"Sun"),(2,"Mon"),(3,"Tue"),(4,"Wed"),(5,"Thu"),(6,"Fri"),(7,"Sat")]
    private let areas = ["Mobility","Strength","Power","HIIT","NEAT/LISS"]

    @State private var selectedWeekday: Int = 2 // default Monday
    @State private var plan: Plan = PlanStore.load()
    @State private var alertMessage: String?

    var body: some View {
        NavigationStack {
            ZStack { NeonMotionBackground() }
                .overlay(
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Weekly Planner", subtitle: "Tap a day, toggle focus areas")

                            DaySelector(days: days, selected: $selectedWeekday)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Focus on \(label(for: selectedWeekday))")
                                    .font(.headline)

                                // precompute to help the type-checker
                                let selectedAreas = plan.days[selectedWeekday] ?? []

                                ForEach(areas, id: \.self) { a in
                                    Toggle(isOn: Binding(
                                        get: { selectedAreas.contains(a) },
                                        set: { on in toggleArea(a, on: on) }
                                    )) {
                                        Text(a)
                                    }
                                    .toggleStyle(.switch)
                                }
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 16)

                            Legend()

                            HStack(spacing: 12) {
                                Button("Save Plan") { PlanStore.save(plan) }
                                    .buttonStyle(AtlasButtonStyle())

                                Button("Apply to Reminders") { applyReminders() }
                                    .buttonStyle(AtlasButtonStyle(gradient: AtlasTheme.gradientAlt))
                            }
                        }
                        .padding(20)
                    }
                )
                .navigationTitle("Plan")
        }
        .onChange(of: plan) { newPlan in
            PlanStore.save(newPlan)
        }
        .alert(
            "Heads up",
            isPresented: Binding(get: { alertMessage != nil }, set: { _ in alertMessage = nil })
        ) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func toggleArea(_ area: String, on: Bool) {
        var arr = plan.days[selectedWeekday] ?? []
        if on {
            if !arr.contains(area) { arr.append(area) }
        } else {
            arr.removeAll { $0 == area }
        }
        plan.days[selectedWeekday] = arr.isEmpty ? nil : arr
    }

    private func label(for day: Int) -> String {
        days.first { $0.0 == day }?.1 ?? "Day"
    }
}

// MARK: - Day Selector

private struct DaySelector: View {
    let days: [(Int, String)]
    @Binding var selected: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.0) { d in
                Button(action: { selected = d.0 }) {
                    Text(d.1)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selected == d.0
                            ? AtlasTheme.gradient
                            : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom)
                        )
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Legend

private struct Legend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Legend").font(.headline)
            Wrap(spacing: 8) {
                LegendChip(text: "Mobility")
                LegendChip(text: "Strength")
                LegendChip(text: "Power")
                LegendChip(text: "HIIT")
                LegendChip(text: "NEAT/LISS")
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 16)
    }
}

private struct LegendChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(AtlasTheme.gradient.opacity(0.25)))
    }
}

// MARK: - Local plan persistence & scheduling (scoped to this file)

extension WeeklyPlannerView {
    struct Plan: Codable, Equatable { var days: [Int: [String]] = [:] }

    enum PlanStore {
        private static let key = "weeklyPlan"
        static func load() -> Plan {
            guard
                let data = UserDefaults.standard.data(forKey: key),
                let p = try? JSONDecoder().decode(Plan.self, from: data)
            else { return Plan() }
            return p
        }
        static func save(_ plan: Plan) {
            if let data = try? JSONEncoder().encode(plan) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    func applyReminders() {
        let weekdays = plan.days.keys.sorted()
        guard !weekdays.isEmpty else {
            alertMessage = "Select at least one training day before applying reminders."
            return
        }
        // Load reminder time from stored profile
        guard
            let data = UserDefaults.standard.data(forKey: "userProfile"),
            let profile = try? JSONDecoder().decode(UserProfile.self, from: data),
            let time = profile.reminderTime
        else {
            alertMessage = "Enable reminders and pick a time in Edit Profile first."
            return
        }

        let center = UNUserNotificationCenter.current()
        // Clear old identifiers (daily + weekday-specific)
        let allIDs = ["atlasfit.dailyReminder"] + (1...7).map { "atlasfit.reminder.\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: allIDs)

        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        for wd in weekdays { // 1=Sun … 7=Sat
            var dc = DateComponents()
            dc.weekday = wd
            dc.hour    = comps.hour
            dc.minute  = comps.minute

            let content = UNMutableNotificationContent()
            content.title = "Time to train"
            content.body  = "Small steps today → big changes tomorrow."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            let id = "atlasfit.reminder.\(wd)"
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
        alertMessage = "Reminders scheduled for \(weekdays.count) day(s) per week."
    }
}

#Preview { WeeklyPlannerView() }
