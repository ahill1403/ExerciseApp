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
    @State private var showTemplatePicker = false
    @State private var showBuildFromScratch = false

    @State private var completionMessage: String?

    var body: some View {
        ZStack {
            NeonMotionBackground()

            let sessionTransition = motion.reduceMotion
                ? AnyTransition.opacity
                : AnyTransition.move(edge: .bottom).combined(with: .opacity)

            if !vm.isLogging {
                homeContent
                    .transition(sessionTransition)
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
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerSheet(
                templates: vm.templates,
                expandedTemplateID: $expandedTemplateID,
                showAllTemplates: $showAllTemplates,
                onStartTemplate: { name in
                    vm.start(template: name)
                    expandedTemplateID = nil
                    showTemplatePicker = false
                },
                onStartCustom: {
                    vm.start(template: "Custom")
                    expandedTemplateID = nil
                    showTemplatePicker = false
                }
            )
        }
        .sheet(isPresented: $showBuildFromScratch) {
            BuildFromScratchSheet(
                catalog: WorkoutCatalog.shared.all,
                onStart: { selections in
                    vm.startFromScratch(with: selections)
                    showBuildFromScratch = false
                },
                onSkip: {
                    vm.startFromScratch(with: [])
                    showBuildFromScratch = false
                }
            )
        }
    }

    // MARK: - Home (pre-session) content
    private var homeContent: some View {
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

    private var emptySessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prefer to freestyle?")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Start an empty log and build the workout as you go.")
                .font(.footnote)
                .foregroundColor(.secondary)

            Button("Start Empty Session") {
                showBuildFromScratch = true
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

// MARK: - Template picker

private struct TemplatePickerSheet: View {
    let templates: [StartWorkoutViewModel.TemplateInfo]
    @Binding var expandedTemplateID: StartWorkoutViewModel.TemplateInfo.ID?
    @Binding var showAllTemplates: Bool
    var onStartTemplate: (String) -> Void
    var onStartCustom: () -> Void

    @State private var searchText = ""
    @State private var selectedEquipment: String?
    @State private var selectedDuration: String?
    @State private var selectedFocus: String?

    @Environment(\.dismiss) private var dismiss

    private let templateColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var equipmentOptions: [String] {
        Array(Set(templates.map(\.equipment))).sorted()
    }

    private var durationOptions: [String] {
        Array(Set(templates.map(\.duration))).sorted()
    }

    private var focusOptions: [String] {
        Array(Set(templates.map(\.focus))).sorted()
    }

    private var filteredTemplates: [StartWorkoutViewModel.TemplateInfo] {
        templates.filter { template in
            (searchText.isEmpty || template.name.localizedCaseInsensitiveContains(searchText)) &&
            (selectedEquipment == nil || template.equipment == selectedEquipment) &&
            (selectedDuration == nil || template.duration == selectedDuration) &&
            (selectedFocus == nil || template.focus == selectedFocus)
        }
    }

    private var templatesToShow: [StartWorkoutViewModel.TemplateInfo] {
        let results = filteredTemplates
        return showAllTemplates ? results : Array(results.prefix(2))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Build your session from scratch or start from a template.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button {
                        onStartCustom()
                        dismiss()
                    } label: {
                        Label("Build your own workout", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AtlasButtonStyle())

                    Divider()
                        .padding(.vertical, 4)

                    Text("Choose a template")
                        .font(.title2.bold())
                        .gradientForeground()

                    Text("Use one of our curated plans as a starting point, then edit anything you like.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    TemplateSearchField(text: $searchText)

                    TemplateFilters(
                        equipmentOptions: equipmentOptions,
                        durationOptions: durationOptions,
                        focusOptions: focusOptions,
                        selectedEquipment: $selectedEquipment,
                        selectedDuration: $selectedDuration,
                        selectedFocus: $selectedFocus
                    )

                    LazyVGrid(columns: templateColumns, spacing: 14) {
                        ForEach(templatesToShow) { template in
                            let isExpanded = expandedTemplateID == template.id
                            TemplateCard(
                                template: template,
                                isExpanded: isExpanded,
                                onToggle: {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                        expandedTemplateID = isExpanded ? nil : template.id
                                    }
                                },
                                onStart: {
                                    onStartTemplate(template.name)
                                    dismiss()
                                }
                            )
                        }
                    }

                    if filteredTemplates.count > 2 {
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                showAllTemplates.toggle()
                            }
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
                .padding(20)
            }
            .navigationTitle("Start Empty Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .onAppear {
            expandedTemplateID = nil
            showAllTemplates = false
            searchText = ""
            selectedEquipment = nil
            selectedDuration = nil
            selectedFocus = nil
        }
    }
}

private struct BuildFromScratchSheet: View {
    let catalog: [WorkoutDefinition]
    var onStart: ([WorkoutDefinition]) -> Void
    var onSkip: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedMuscle: FitnessArea?
    @State private var selectedEquipment: String?
    @State private var selectedType: String?
    @State private var stagedSelections: Set<String> = []

    private var muscleOptions: [FitnessArea] { FitnessArea.allCases }
    private var equipmentOptions: [String] { Array(Set(catalog.map(\.equipment))).sorted() }
    private var typeOptions: [String] { Array(Set(catalog.map(\.sessionTypeTag))).sorted() }

    private var filteredExercises: [WorkoutDefinition] {
        catalog.filter { exercise in
            let matchesSearch = searchText.isEmpty
                || exercise.name.localizedCaseInsensitiveContains(searchText)
                || exercise.summary.localizedCaseInsensitiveContains(searchText)

            let matchesMuscle = selectedMuscle.map { $0 == exercise.area } ?? true
            let matchesEquipment = selectedEquipment.map { $0 == exercise.equipment } ?? true
            let matchesType = selectedType.map { $0 == exercise.sessionTypeTag } ?? true

            return matchesSearch && matchesMuscle && matchesEquipment && matchesType
        }
    }

    private var selectedExercises: [WorkoutDefinition] {
        catalog.filter { stagedSelections.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Queue movements before you start logging. Use filters to add focused work without committing to a template.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TemplateSearchField(text: $searchText, placeholder: "Search exercises")

                    VStack(alignment: .leading, spacing: 12) {
                        FilterSection(
                            title: "Muscle group",
                            options: muscleOptions.map { $0.displayName },
                            selection: Binding(
                                get: { selectedMuscle?.displayName },
                                set: { newValue in selectedMuscle = muscleOptions.first { $0.displayName == newValue } }
                            ),
                            animation: .spring(response: 0.32, dampingFraction: 0.86)
                        )

                        FilterSection(
                            title: "Equipment",
                            options: equipmentOptions,
                            selection: $selectedEquipment,
                            animation: .spring(response: 0.32, dampingFraction: 0.86)
                        )

                        FilterSection(
                            title: "Duration / type",
                            options: typeOptions,
                            selection: $selectedType,
                            animation: .spring(response: 0.32, dampingFraction: 0.86)
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Exercise library")
                                .font(.title3.bold())
                                .gradientForeground()
                            Spacer()
                            Text("\(filteredExercises.count) shown")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                        }

                        VStack(spacing: 12) {
                            ForEach(filteredExercises, id: \.id) { exercise in
                                ScratchExerciseRow(
                                    exercise: exercise,
                                    isSelected: stagedSelections.contains(exercise.id),
                                    onToggle: {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                            if stagedSelections.contains(exercise.id) {
                                                stagedSelections.remove(exercise.id)
                                            } else {
                                                stagedSelections.insert(exercise.id)
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }

                    Divider().opacity(0.14)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(selectedExercises.count) exercises queued")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("We'll open the logger with these queued so you can add sets right away. You can still add or remove anything inside the session.")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        Button {
                            onStart(selectedExercises)
                            dismiss()
                        } label: {
                            Label(
                                selectedExercises.isEmpty ? "Start logging from scratch" : "Start with \(selectedExercises.count) exercises",
                                systemImage: "play.fill"
                            )
                        }
                        .buttonStyle(AtlasButtonStyle())

                        if selectedExercises.isEmpty {
                            Button {
                                onSkip()
                                dismiss()
                            } label: {
                                Label("Skip and add as you go", systemImage: "rectangle.dashed")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AtlasTheme.cardFill.opacity(0.9))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(AtlasTheme.border, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Build from scratch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .onAppear {
                searchText = ""
                selectedMuscle = nil
                selectedEquipment = nil
                selectedType = nil
            }
        }
    }
}

private struct TemplateSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search templates"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.words)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AtlasTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AtlasTheme.border, lineWidth: 1)
        )
    }
}

private struct TemplateFilters: View {
    let equipmentOptions: [String]
    let durationOptions: [String]
    let focusOptions: [String]

    @Binding var selectedEquipment: String?
    @Binding var selectedDuration: String?
    @Binding var selectedFocus: String?

    private let animation = Animation.spring(response: 0.32, dampingFraction: 0.86)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !equipmentOptions.isEmpty {
                FilterSection(title: "Equipment", options: equipmentOptions, selection: $selectedEquipment, animation: animation)
            }

            if !durationOptions.isEmpty {
                FilterSection(title: "Duration", options: durationOptions, selection: $selectedDuration, animation: animation)
            }

            if !focusOptions.isEmpty {
                FilterSection(title: "Focus", options: focusOptions, selection: $selectedFocus, animation: animation)
            }
        }
    }
}

private struct FilterSection: View {
    let title: String
    let options: [String]
    @Binding var selection: String?
    let animation: Animation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    FilterChip(title: "All", isSelected: selection == nil) {
                        withAnimation(animation) { selection = nil }
                    }

                    ForEach(options, id: \.self) { option in
                        FilterChip(title: option, isSelected: selection == option) {
                            withAnimation(animation) { selection = selection == option ? nil : option }
                        }
                    }
                }
            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        isSelected ? AtlasTheme.gradient : AtlasTheme.cardFill
                    )
                )
                .foregroundStyle(isSelected ? Color.white : .secondary)
        }
        .buttonStyle(.plain)
    }
}

private struct ScratchExerciseRow: View {
    let exercise: WorkoutDefinition
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(exercise.area.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AtlasTheme.gradient.opacity(0.16), in: Capsule())
                }

                Spacer()

                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? AtlasTheme.gradient : .secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                Label(exercise.equipment, systemImage: "dumbbell.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()
                    .frame(height: 14)
                    .overlay(Color.secondary.opacity(0.22))

                Text(exercise.sessionTypeTag)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(exercise.summary)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AtlasTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? AtlasTheme.gradient : AtlasTheme.border, lineWidth: isSelected ? 1.4 : 1)
        )
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
