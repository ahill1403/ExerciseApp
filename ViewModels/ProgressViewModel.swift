import Foundation

enum ProgressRange: String, CaseIterable, Identifiable {
    case weekly
    case monthly

    var id: Self { self }

    var pickerTitle: String {
        switch self {
        case .weekly: return "Weeks"
        case .monthly: return "Months"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .weekly: return .weekOfYear
        case .monthly: return .month
        }
    }

    var periodCount: Int {
        switch self {
        case .weekly: return 8
        case .monthly: return 6
        }
    }

    func anchorDate(for referenceDate: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: component, for: referenceDate)?.start ?? referenceDate
    }

    func label(for date: Date, calendar: Calendar) -> String {
        switch self {
        case .weekly:
            return ProgressRange.weekFormatter.string(from: date)
        case .monthly:
            return ProgressRange.monthFormatter.string(from: date)
        }
    }

    private static let weekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }()
}

enum ProgressMetric: CaseIterable, Identifiable {
    case workouts
    case weight
    case reps
    case duration

    var id: Self { self }

    var title: String {
        switch self {
        case .workouts: return "Workouts Completed"
        case .weight: return "Weight Lifted"
        case .reps: return "Reps Completed"
        case .duration: return "Duration"
        }
    }

    func yAxisLabel(units: Units) -> String {
        switch self {
        case .workouts: return "Workouts"
        case .weight: return "Weight (\(units.rawValue))"
        case .reps: return "Reps"
        case .duration: return "Minutes"
        }
    }

    func summary(for total: Double, units: Units) -> String {
        switch self {
        case .workouts:
            return "Total \(Int(total.rounded())) workouts"
        case .weight:
            return "Total \(ProgressMetric.numberFormatter.string(from: NSNumber(value: total)) ?? "0") \(units.rawValue) lifted"
        case .reps:
            return "Total \(Int(total.rounded())) reps"
        case .duration:
            return "Total \(ProgressMetric.numberFormatter.string(from: NSNumber(value: total)) ?? "0") min"
        }
    }

    func formattedValue(_ value: Double) -> String {
        switch self {
        case .workouts, .reps:
            return String(Int(value.rounded()))
        case .weight, .duration:
            return ProgressMetric.numberFormatter.string(from: NSNumber(value: value)) ?? "0"
        }
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

struct ProgressDataPoint: Identifiable {
    let periodStart: Date
    let label: String
    let value: Double

    var id: Date { periodStart }
}

@MainActor
final class ProgressViewModel: ObservableObject {
    @Published private(set) var sessions: [WorkoutSession] = []
    @Published private(set) var workoutsThisWeek: Int = 0
    @Published private(set) var streakDays: Int = 0
    @Published private(set) var lastWorkout: Date?
    @Published private(set) var preferredUnits: Units = UserProfileStore.load()?.units ?? .lbs

    init() { refresh() }

    func refresh() {
        sessions = WorkoutStore.shared.load().sorted(by: { $0.date > $1.date })
        workoutsThisWeek = WorkoutStore.shared.workoutsThisWeek(firstWeekday: 1)
        streakDays = WorkoutStore.shared.currentStreakDays()
        lastWorkout = WorkoutStore.shared.lastWorkoutDate()
        preferredUnits = UserProfileStore.load()?.units ?? .lbs
    }

    func chartData(for metric: ProgressMetric, range: ProgressRange) -> [ProgressDataPoint] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1

        let anchor = range.anchorDate(for: Date(), calendar: calendar)
        let grouped = Dictionary(grouping: sessions) { session in
            range.anchorDate(for: session.date, calendar: calendar)
        }

        return (0..<range.periodCount).reversed().compactMap { offset -> ProgressDataPoint? in
            guard let periodStart = calendar.date(byAdding: range.component, value: -offset, to: anchor) else { return nil }
            let periodSessions = grouped[periodStart] ?? []
            let value = metricValue(for: metric, sessions: periodSessions)
            return ProgressDataPoint(
                periodStart: periodStart,
                label: range.label(for: periodStart, calendar: calendar),
                value: value
            )
        }
    }

    private func metricValue(for metric: ProgressMetric, sessions: [WorkoutSession]) -> Double {
        switch metric {
        case .workouts:
            return Double(sessions.count)
        case .weight:
            return sessions.reduce(0) { total, session in
                total + session.exercises.reduce(0) { exerciseTotal, exercise in
                    exerciseTotal + exercise.sets.reduce(0) { setTotal, set in
                        let converted = convertWeight(set.weight, from: set.units, to: preferredUnits)
                        return setTotal + (converted * Double(set.reps))
                    }
                }
            }
        case .reps:
            return Double(sessions.reduce(0) { $0 + $1.totalReps })
        case .duration:
            let totalSeconds = sessions.reduce(0) { $0 + ( $1.duration ?? 0 ) }
            return totalSeconds / 60
        }
    }

    private func convertWeight(_ value: Double, from fromUnit: Units, to toUnit: Units) -> Double {
        guard fromUnit != toUnit else { return value }
        switch (fromUnit, toUnit) {
        case (.kgs, .lbs):
            return value * 2.20462
        case (.lbs, .kgs):
            return value / 2.20462
        default:
            return value
        }
    }
}
