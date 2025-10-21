import SwiftUI

struct WeekPlanGrid: View {
    let plan: WeeklyPlan
    private let onSelectDay: ((Int) -> Void)?
    private let calendar: Calendar
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    init(plan: WeeklyPlan, onSelectDay: ((Int) -> Void)? = nil) {
        self.plan = plan
        self.onSelectDay = onSelectDay
        var cal = Calendar.current
        cal.firstWeekday = 1 // Sunday baseline for display
        self.calendar = cal
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(1...7, id: \.self) { day in
                let card = dayCard(for: day)
                if let onSelectDay {
                    Button(action: { onSelectDay(day) }) {
                        card
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(for: day))
                } else {
                    card
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(accessibilityLabel(for: day))
                }
            }
        }
    }

    private func dayCard(for day: Int) -> some View {
        let info = dayInfo(for: day)
        let workouts = WorkoutCatalog.shared.workouts(forIDs: plan.workoutIDs(for: day))
        let focusAreas = plan.focusAreas(for: day)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.label.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(info.dateString)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }
                Spacer()
                if info.isToday {
                    Text("Today")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AtlasTheme.gradient.opacity(0.32), in: Capsule())
                        .foregroundStyle(.white)
                }
            }

            if !focusAreas.isEmpty {
                Text(focusAreas.map { $0.displayName }.joined(separator: " • "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .opacity(0.18)

            if workouts.isEmpty {
                if focusAreas.isEmpty {
                    Text("Rest day")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text("No workouts added yet. Tap to choose moves for this focus.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(workouts) { workout in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: icon(for: workout.area))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AtlasTheme.accentGreen)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(workout.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AtlasTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    info.isToday ? AtlasTheme.gradient : AtlasTheme.border,
                    lineWidth: info.isToday ? 2 : 1
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
    }

    private func dayInfo(for day: Int) -> (label: String, dateString: String, isToday: Bool) {
        let start = startOfWeek()
        let dayOffset = ((day - calendar.firstWeekday) + 7) % 7
        let date = calendar.date(byAdding: .day, value: dayOffset, to: start) ?? start
        let labelIndex = (day - 1 + calendar.shortWeekdaySymbols.count) % calendar.shortWeekdaySymbols.count
        let label = calendar.shortWeekdaySymbols[labelIndex]
        let components = calendar.dateComponents([.month, .day], from: date)
        let monthIndex = max(0, min((components.month ?? 1) - 1, calendar.shortMonthSymbols.count - 1))
        let month = calendar.shortMonthSymbols[monthIndex]
        let dayNumber = components.day ?? 1
        let dateString = "\(month) \(dayNumber)"
        return (label, dateString, calendar.isDateInToday(date))
    }

    private func startOfWeek() -> Date {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let difference = ((weekday - calendar.firstWeekday) + 7) % 7
        return calendar.date(byAdding: .day, value: -difference, to: today) ?? today
    }

    private func icon(for area: FitnessArea) -> String {
        switch area {
        case .strength: return "dumbbell.fill"
        case .mobility: return "figure.cooldown"
        case .power: return "bolt.fill"
        case .hiit: return "flame.fill"
        case .neat: return "figure.walk"
        }
    }

    private func accessibilityLabel(for day: Int) -> String {
        let info = dayInfo(for: day)
        let workouts = WorkoutCatalog.shared.workouts(forIDs: plan.workoutIDs(for: day))
        if workouts.isEmpty {
            if plan.focusAreas(for: day).isEmpty {
                return "\(info.label) \(info.dateString). Rest day."
            } else {
                let focus = plan.focusAreas(for: day).map { $0.displayName }.joined(separator: ", ")
                return "\(info.label) \(info.dateString). Focus: \(focus). No workouts chosen yet."
            }
        } else {
            let names = workouts.map { $0.name }.joined(separator: ", ")
            return "\(info.label) \(info.dateString). Planned workouts: \(names)."
        }
    }
}
