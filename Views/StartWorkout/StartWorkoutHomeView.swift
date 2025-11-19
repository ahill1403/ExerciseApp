import SwiftUI

extension StartWorkoutView {
    // MARK: - Home (pre-session) content
    var homeContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                planRecommendationSection
                emptySessionSection
            }
            .padding(20)
        }
        .tabBarAware()
    }

    @ViewBuilder
    var planRecommendationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("From your weekly planner", systemImage: "calendar")
                .font(.title2.bold())
                .gradientForeground()

            WeekSchedulePeek(plan: planSnapshot)

            if let suggestion = vm.planSuggestion,
               let firstTemplate = suggestion.templates.first,
               let templateInfo = vm.info(for: firstTemplate) {

                let dayName = weekdayName(for: suggestion.day)
                let focusSummary = suggestion.areas.map { $0.displayName }.joined(separator: " • ")

                VStack(alignment: .leading, spacing: 8) {
                    let header = suggestion.isToday
                    ? "Today's recommendation"
                    : (suggestion.offset == 1 ? "Tomorrow's recommendation" : "\(dayName)'s recommendation")

                    Text(header)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(focusSummary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 10) {
                    ForEach(suggestion.areas, id: \.self) { area in
                        Text(area.displayName)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AtlasTheme.gradient.opacity(0.18), in: Capsule())
                    }
                    Spacer(minLength: 0)
                }

                Text("\(templateInfo.duration) • \(templateInfo.equipment)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(templateInfo.summary)
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Button {
                    vm.start(template: firstTemplate)
                    expandedTemplateID = nil
                } label: {
                    Label(suggestion.isToday ? "Start Today's Plan" : "Start \(dayName)", systemImage: "play.fill")
                }
                .buttonStyle(AtlasButtonStyle())

                if suggestion.templates.count > 1 {
                    Divider().opacity(0.12)

                    Text("Other planner-aligned options")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 6) {
                        ForEach(Array(suggestion.templates.dropFirst()), id: \.self) { name in
                            Button {
                                vm.start(template: name)
                                expandedTemplateID = nil
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.turn.down.right")
                                    Text(name)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AtlasTheme.cardFill.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    NavigationLink {
                        WeeklyPlannerView()
                    } label: {
                        Label("Open Weekly Planner", systemImage: "calendar.badge.plus")
                    }
                    .buttonStyle(AtlasButtonStyle())

                    Button {
                        withAnimation(motion.primary) {
                            showTemplatePicker = true
                        }
                    } label: {
                        Label("Pick a template now", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AtlasTheme.cardFill.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AtlasTheme.border, lineWidth: 1)
                    )
                }
            }

            Text("Manage your schedule anytime from the Plan tab.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .glassCard(cornerRadius: 22)
    }

    var emptySessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prefer to freestyle?")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Start an empty log and build the workout as you go.")
                .font(.footnote)
                .foregroundColor(.secondary)

            Button("Start Empty Session") {
                showTemplatePicker = true
            }
            .buttonStyle(AtlasButtonStyle())
        }
        .padding(20)
        .glassCard(cornerRadius: 22)
    }

    func weekdayName(for day: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let idx = (day - 1 + symbols.count) % symbols.count
        return symbols[idx]
    }
}

struct WeekSchedulePeek: View {
    let plan: WeeklyPlan

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 1
        return cal
    }

    private var today: Int { Calendar.current.component(.weekday, from: Date()) }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...7, id: \.self) { day in
                let label = shortLabel(for: day)
                let hasFocus = !plan.focusAreas(for: day).isEmpty
                let isToday = day == today

                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(hasFocus ? .white : .secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(hasFocus ? AtlasTheme.gradient : AtlasTheme.cardFill)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                (isToday ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(AtlasTheme.border)),
                                lineWidth: isToday ? 2 : 1
                            )
                    )
                    .accessibilityLabel(accessibilityLabel(for: day, hasFocus: hasFocus))
            }
        }
    }

    private func shortLabel(for day: Int) -> String {
        let symbols = calendar.shortWeekdaySymbols
        let index = (day - 1 + symbols.count) % symbols.count
        return String(symbols[index].prefix(1))
    }

    private func accessibilityLabel(for day: Int, hasFocus: Bool) -> String {
        let name = calendar.weekdaySymbols[(day - 1 + calendar.weekdaySymbols.count) % calendar.weekdaySymbols.count]
        var components = [name]
        components.append(hasFocus ? "training day" : "rest day")
        if day == today { components.append("today") }
        return components.joined(separator: ", ")
    }
}
