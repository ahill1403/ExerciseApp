//
//  StartWorkoutView.swift
//  REPS
//
//  Created by Aaron Hill on 9/11/25.
//

import SwiftUI

struct StartWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.atlasMotion) private var motion
    @StateObject private var vm = StartWorkoutViewModel()

    // UI state only used on the home screen
    @State private var planSnapshot: WeeklyPlan = PlannerStore.shared.load()
    @State private var expandedTemplateID: StartWorkoutViewModel.TemplateInfo.ID?
    @State private var showAllTemplates = false

    private let templateColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]
    @State private var completionMessage: String?

    var body: some View {
        ZStack {
            NeonMotionBackground()

            let sessionTransition = motion.reduceMotion
                ? AnyTransition.opacity
                : AnyTransition.move(edge: .bottom).combined(with: .opacity)

            if !vm.isLogging {
                homeContent
            } else {
                WorkoutSessionView(vm: vm)
                    .transition(sessionTransition)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                AtlasNavigationTitle(
                    title: vm.isLogging ? "Workout Session" : "Start Workout",
                    subtitle: vm.isLogging ? "Log sets and reps" : "Choose the next session"
                )
            }
        }
        .atlasNavigationBarStyle()
        .onAppear {
            vm.refreshPlanSuggestion()
            planSnapshot = PlannerStore.shared.load()
        }
        .onChange(of: vm.planSuggestion?.day) {
            // keep the planner peek in sync
            planSnapshot = PlannerStore.shared.load()
        }
        .overlay(alignment: .top) {
            if let message = completionMessage {
                EncouragementBanner(message: message)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .transition(motion.bannerTransition)
            }
        }
        .animation(motion.primary, value: completionMessage)
        .animation(motion.primary, value: vm.isLogging)
        .onAppear {
            NotificationCenter.default.post(name: .atlasLoggingStateChanged, object: vm.isLogging)
        }
        .onChange(of: vm.isLogging) { isLogging in
            NotificationCenter.default.post(name: .atlasLoggingStateChanged, object: isLogging)

            if isLogging {
                withAnimation(motion.primary) { completionMessage = nil }
            } else if let message = vm.lastCompletionMessage, completionMessage != message {
                presentCompletionMessage(message)
            }
        }
        .onChange(of: vm.lastCompletionMessage) { message in
            guard vm.isLogging == false, let message else { return }
            if completionMessage != message {
                presentCompletionMessage(message)
            }
        }
    }

    // MARK: - Home (pre-session) content
    private var homeContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                planRecommendationSection
                templatesSection
                emptySessionSection
            }
            .padding(20)
        }
        .tabBarAware()
    }

    @ViewBuilder
    private var planRecommendationSection: some View {
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
                Text("Set at least one training day in Weekly Planner to unlock a daily recommendation here.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Manage your schedule anytime from the Plan tab.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .glassCard(cornerRadius: 22)
    }

    private var templatesSection: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("Choose a template")
                .font(.title2.bold())
                .gradientForeground()
                .padding(.top, 15)

            Text("Curated sessions you can start in one tap.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom, 2)

            let templatesToShow = showAllTemplates ? vm.templates : Array(vm.templates.prefix(2))

            LazyVGrid(columns: templateColumns, spacing: 14) {
                ForEach(templatesToShow) { template in
                    let isExpanded = expandedTemplateID == template.id
                    TemplateCard(
                        template: template,
                        isExpanded: isExpanded,
                        onToggle: {
                            withAnimation(motion.micro) {
                                expandedTemplateID = isExpanded ? nil : template.id
                            }
                        },
                        onStart: {
                            vm.start(template: template.name)
                            expandedTemplateID = nil
                        }
                    )
                }
            }
            .animation(motion.micro, value: expandedTemplateID)

            if vm.templates.count > 2 {
                Button {
                    withAnimation(motion.micro) { showAllTemplates.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Text(showAllTemplates ? "Show fewer" : "More templates")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: showAllTemplates ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AtlasTheme.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AtlasTheme.border, lineWidth: 1)
                )
            }
        }
        .glassCard(cornerRadius: 22)
    }

    private var emptySessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prefer to freestyle?")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Start an empty log and build the workout as you go.")
                .font(.footnote)
                .foregroundColor(.secondary)

            Button("Start Empty Session") {
                vm.start(template: "Custom")
                expandedTemplateID = nil
            }
            .buttonStyle(AtlasButtonStyle())
        }
        .padding(20)
        .glassCard(cornerRadius: 22)
    }

    private func weekdayName(for day: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let idx = (day - 1 + symbols.count) % symbols.count
        return symbols[idx]
    }
}

private extension StartWorkoutView {
    func presentCompletionMessage(_ message: String) {
        completionMessage = message

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(motion.relaxed) {
                completionMessage = nil
            }
            vm.lastCompletionMessage = nil
        }
    }
}

private struct EncouragementBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AtlasTheme.gradient)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AtlasTheme.textPrimary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AtlasTheme.bgElevated.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AtlasTheme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout complete. \(message)")
    }
}

// MARK: - Home-only components

private struct TemplateCard: View {
    let template: StartWorkoutViewModel.TemplateInfo
    let isExpanded: Bool
    let onToggle: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 14 : 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(template.duration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(template.focus)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AtlasTheme.gradient.opacity(0.18), in: Capsule())

                    Label(template.equipment, systemImage: "dumbbell.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(template.summary)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button { onStart() } label: { Label("Start workout", systemImage: "play.fill") }
                        .buttonStyle(AtlasButtonStyle())
                        .padding(.top, 2)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AtlasTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AtlasTheme.border, lineWidth: 1)
        )
    }
}

private struct WeekSchedulePeek: View {
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
