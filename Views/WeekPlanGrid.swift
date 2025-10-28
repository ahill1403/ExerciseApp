import SwiftUI

struct WeekPlanGrid: View {
    let plan: WeeklyPlan
    private let onSelectDay: ((Int) -> Void)?
    private let calendar: Calendar

    private let externalExpandedDay: Binding<Int>?
    @State private var internalExpandedDay: Int

    init(plan: WeeklyPlan, expandedDay: Binding<Int>, onSelectDay: ((Int) -> Void)? = nil) {
        self.plan = plan
        self.onSelectDay = onSelectDay
        self.externalExpandedDay = expandedDay
        _internalExpandedDay = State(initialValue: expandedDay.wrappedValue)

        var cal = Calendar.current
        cal.firstWeekday = 1 // Sunday baseline for display
        self.calendar = cal
    }

    init(plan: WeeklyPlan, onSelectDay: ((Int) -> Void)? = nil) {
        self.plan = plan
        self.onSelectDay = onSelectDay
        self.externalExpandedDay = nil
        _internalExpandedDay = State(initialValue: WeekPlanGrid.defaultExpandedDay(for: plan))

        var cal = Calendar.current
        cal.firstWeekday = 1
        self.calendar = cal
    }

    private var expandedDay: Binding<Int> {
        Binding(
            get: { externalExpandedDay?.wrappedValue ?? internalExpandedDay },
            set: { newValue in
                if let external = externalExpandedDay {
                    external.wrappedValue = newValue
                } else {
                    internalExpandedDay = newValue
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            daySelector

            detailCard(for: expandedDay.wrappedValue)
                .id(expandedDay.wrappedValue)
                .transition(.move(edge: .top).combined(with: .opacity))
                .contentTransition(.opacity)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: expandedDay.wrappedValue)
        .onChange(of: plan) { _, newValue in
            let current = expandedDay.wrappedValue
            if !(1...7).contains(current) {
                expandedDay.wrappedValue = WeekPlanGrid.defaultExpandedDay(for: newValue)
            }
        }
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(1...7, id: \.self) { day in
                    dayCircle(for: day)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
    }

    private func dayCircle(for day: Int) -> some View {
        let info = dayInfo(for: day)
        let abbreviation = String(info.label.prefix(3)).uppercased()
        let focus = plan.focusAreas(for: day)
        let hasWorkouts = !plan.workoutIDs(for: day).isEmpty
        let isSelected = expandedDay.wrappedValue == day

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                expandedDay.wrappedValue = day
            }
        } label: {
            VStack(spacing: 6) {
                if info.isToday {
                    Text("TODAY")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AtlasTheme.accentGreen)
                        .transition(.scale.combined(with: .opacity))
                }

                ZStack {
                    Circle()
                        .fill(isSelected ? AtlasTheme.gradient : AtlasTheme.cardFill)
                        .overlay(
                            Circle()
                                .strokeBorder(isSelected ? AtlasTheme.gradient : AtlasTheme.border, lineWidth: isSelected ? 2 : 1)
                        )
                        .shadow(color: Color.black.opacity(isSelected ? 0.18 : 0.08), radius: isSelected ? 16 : 10, x: 0, y: isSelected ? 10 : 6)

                    Text(abbreviation)
                        .font(.headline.bold())
                        .foregroundStyle(isSelected ? Color.white : AtlasTheme.textPrimary)
                        .accessibilityHidden(true)

                    if hasWorkouts {
                        Circle()
                            .fill(AtlasTheme.accentGreen.opacity(0.85))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.65), lineWidth: 2)
                            )
                            .offset(x: 22, y: 22)
                    }
                }
                .frame(width: 68, height: 68)
                .scaleEffect(isSelected ? 1.08 : 1)
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isSelected)

                Text(focusSummary(for: focus))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? AtlasTheme.textPrimary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: day))
    }

    @ViewBuilder
    private func detailCard(for day: Int) -> some View {
        let info = dayInfo(for: day)
        let focus = plan.focusAreas(for: day)
        let workouts = WorkoutCatalog.shared.workouts(forIDs: plan.workoutIDs(for: day))

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.fullName)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text(info.dateString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let onSelectDay {
                    Button {
                        onSelectDay(day)
                    } label: {
                        Label("Edit", systemImage: "square.and.pencil")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AtlasTheme.gradient.opacity(0.20), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit plan for \(info.fullName)")
                }
            }

            if info.isToday {
                Text("You're looking at today's schedule.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if focus.isEmpty {
                Text("No focus areas yet — mark this as a rest day or add workouts above.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Focus")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach(focus, id: \.self) { area in
                        Text(shortLabel(for: area))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AtlasTheme.gradient.opacity(0.18), in: Capsule())
                    }
                    Spacer(minLength: 0)
                }
            }

            Divider().opacity(0.15)

            if workouts.isEmpty {
                if focus.isEmpty {
                    Text("Tap edit to add guidance or leave it open as a recovery day.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No workouts assigned yet. Add a routine so this focus has structure.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(workouts) { workout in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: icon(for: workout.area))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AtlasTheme.accentGreen)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(workout.summary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 22)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDetailLabel(for: day, info: info, workouts: workouts, focus: focus))
    }

    private func dayInfo(for day: Int) -> DayInfo {
        let start = startOfWeek()
        let dayOffset = ((day - calendar.firstWeekday) + 7) % 7
        let date = calendar.date(byAdding: .day, value: dayOffset, to: start) ?? start
        let shortIndex = (day - 1 + calendar.shortWeekdaySymbols.count) % calendar.shortWeekdaySymbols.count
        let fullIndex = (day - 1 + calendar.weekdaySymbols.count) % calendar.weekdaySymbols.count

        let label = calendar.shortWeekdaySymbols[shortIndex]
        let fullName = calendar.weekdaySymbols[fullIndex]

        let components = calendar.dateComponents([.month, .day], from: date)
        let monthIndex = max(0, min((components.month ?? 1) - 1, calendar.shortMonthSymbols.count - 1))
        let month = calendar.shortMonthSymbols[monthIndex]
        let dayNumber = components.day ?? 1
        let dateString = "\(month) \(dayNumber)"

        return DayInfo(label: label, fullName: fullName, dateString: dateString, isToday: calendar.isDateInToday(date), date: date)
    }

    private func startOfWeek() -> Date {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let difference = ((weekday - calendar.firstWeekday) + 7) % 7
        return calendar.date(byAdding: .day, value: -difference, to: today) ?? today
    }

    private func shortLabel(for area: FitnessArea) -> String {
        switch area {
        case .strength: return "Strength"
        case .mobility: return "Mobility"
        case .power: return "Power"
        case .hiit: return "HIIT"
        case .neat: return "Cardio"
        }
    }

    private func focusSummary(for focus: [FitnessArea]) -> String {
        switch focus.count {
        case 0:  return "Rest"
        case 1:  return shortLabel(for: focus[0])
        case 2:  return "\(shortLabel(for: focus[0])) & \(shortLabel(for: focus[1]))"
        default: return "\(shortLabel(for: focus[0])) +\(focus.count - 1)"
        }
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
                return "\(info.label) \(info.dateString). Focus: \(focus)."
            }
        } else {
            let names = workouts.map { $0.name }.joined(separator: ", ")
            return "\(info.label) \(info.dateString). Planned workouts: \(names)."
        }
    }

    private func accessibilityDetailLabel(for day: Int, info: DayInfo, workouts: [WorkoutDefinition], focus: [FitnessArea]) -> String {
        var components: [String] = ["\(info.fullName) \(info.dateString)"]
        if info.isToday { components.append("Today") }
        if focus.isEmpty {
            components.append("No focus areas")
        } else {
            components.append("Focus: \(focus.map { $0.displayName }.joined(separator: ", "))")
        }
        if workouts.isEmpty {
            components.append("No workouts assigned")
        } else {
            components.append("Workouts: \(workouts.map { $0.name }.joined(separator: ", "))")
        }
        return components.joined(separator: ". ")
    }

    static func defaultExpandedDay(for plan: WeeklyPlan) -> Int {
        let today = Calendar.current.component(.weekday, from: Date())
        if let dayPlan = plan.dayPlan(for: today), !dayPlan.isEmpty {
            return today
        }
        if let firstActive = plan.days.keys.sorted().first {
            return firstActive
        }
        return today
    }

    private struct DayInfo {
        let label: String
        let fullName: String
        let dateString: String
        let isToday: Bool
        let date: Date
    }
}
