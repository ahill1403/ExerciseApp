import SwiftUI

struct OnboardingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = OnboardingViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                NeonMotionBackground()
                
                VStack(spacing: 16) {
                    // Progress: hide on .done to avoid out-of-bounds warning
                    if vm.step != .done {
                        let progress = vm.progress
                        ProgressView(value: progress.value, total: progress.total)
                            .tint(AtlasTheme.neon)
                            .padding(.horizontal, 20)
                    }
                    
                    
                    ScrollView {
                        Group {
                            switch vm.step {
                            case .goal: GoalStep(goal: $vm.data.goal)
                            case .experience:
                                ExperienceStep(
                                    experience: $vm.data.experience,
                                    experienceByArea: $vm.data.experienceByArea
                                )
                            case .frequency:
                                FrequencyStep(
                                    days: $vm.data.daysPerWeek,
                                    minutesPerDay: $vm.data.minutesPerDay
                                )
                            case .reminder: ReminderStep(wants: $vm.data.wantsNotifications, time: $vm.data.reminderTime)
                            case .physique:
                                PhysiqueStep(
                                    gender: $vm.data.gender,
                                    ageRange: $vm.data.ageRange,
                                    heightInCm: $vm.data.heightInCm,
                                    weight: $vm.data.weight,
                                    units: $vm.data.units
                                )
                            case .plan:
                                PlanChoiceStep(
                                    plan: vm.recommendedPlan ?? WeeklyPlan(),
                                    decision: $vm.planDecision
                                )
                            case .done:
                                VStack(spacing: 16) {
                                    Text("You’re set!").font(.title.bold()).gradientForeground()
                                    if vm.data.experience == .novice || vm.planDecision == .recommended {
                                        Text("Your weekly plan is ready to go. Check it anytime under Planner.")
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Jump into the Weekly Planner to craft your own routine.")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(16)
                            }
                        }
                        .glassCard(cornerRadius: 24)
                        .padding(.horizontal, 20)
                        .padding(.top, 0)
                    }
                    .scrollIndicators(.hidden)
                    
                    HStack(spacing: 12) {
                        if vm.step != .goal && vm.step != .done {
                            Button("Back") { vm.back() }
                                .buttonStyle(AtlasButtonStyle(gradient: AtlasTheme.gradientAlt))
                                .frame(maxWidth: 160)
                        }
                        if vm.step != .done {
                            let title = vm.step == .plan ? "Finish" : "Continue"
                            Button(title) { vm.next() }
                                .buttonStyle(AtlasButtonStyle())
                                .disabled(!vm.canContinue)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationTitle("Onboarding")
            .navigationBarTitleDisplayMode(.inline)
            // iOS 17+ onChange variant: two-parameter closure
            .onChange(of: vm.step) { _, newValue in
                if newValue == .done {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Steps

private struct GoalStep: View {
    @Binding var goal: FitnessGoal
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your primary goal").font(.title2.bold()).gradientForeground()
            ForEach(FitnessGoal.allCases) { g in
                SelectRow(title: g.rawValue, isSelected: goal == g) { goal = g }
            }
        }.padding(16)
    }
}

private struct ExperienceStep: View {
    @Binding var experience: TrainingExperience
    @Binding var experienceByArea: [FitnessArea: TrainingExperience]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Training experience").font(.title2.bold()).gradientForeground()
            
            Text("Start with your overall comfort level.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            ForEach(TrainingExperience.allCases) { e in
                SelectRow(title: e.rawValue, isSelected: experience == e) { experience = e }
            }
            
            Divider()
                .overlay(Color.white.opacity(0.2))
                .padding(.vertical, 4)
            
            Text("Dial in each fitness pillar")
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(FitnessArea.allCases) { area in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(area.displayName)
                            .font(.subheadline.weight(.semibold))
                        Picker("Experience", selection: Binding(
                            get: { experienceByArea[area] ?? .novice },
                            set: { experienceByArea[area] = $0 }
                        )) {
                            ForEach(TrainingExperience.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            
            Text("We’ll use this to suggest when to emphasize or skip certain areas.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

private struct FrequencyStep: View {
    @Binding var days: Int
    @Binding var minutesPerDay: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your weekly rhythm").font(.title2.bold()).gradientForeground()
            
            Stepper("Days per week: \(days)", value: $days, in: 1...7)
                .padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Time per day")
                    .font(.headline)
                Stepper("\(minutesPerDay) minutes", value: $minutesPerDay, in: 10...180, step: 5)
                Text("Helps size workouts to fit your schedule.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            Text("You can refine your plan later in Weekly Planner.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

private struct ReminderStep: View {
    @Binding var wants: Bool
    @Binding var time: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reminders").font(.title2.bold()).gradientForeground()
            Toggle("Enable workout reminders", isOn: $wants)
            if wants {
                DatePicker("Reminder time", selection: $time, displayedComponents: .hourAndMinute)
            }
            Text("We’ll ask permission to send notifications. You can change this anytime in Settings.")
                .font(.footnote).foregroundStyle(.secondary)
        }.padding(16)
    }
}

private struct PhysiqueStep: View {
    @Binding var gender: Gender
    @Binding var ageRange: AgeRange
    @Binding var heightInCm: Double
    @Binding var weight: Double
    @Binding var units: Units
    
    @State private var heightMode: HeightMode = .cm
    @State private var feet: Int = 5
    @State private var inches: Int = 9
    
    enum HeightMode: String, CaseIterable, Identifiable { case cm = "cm", imperial = "ft/in"; var id: String { rawValue } }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About you").font(.title2.bold()).gradientForeground()
            
            // Gender
            Picker("Gender", selection: $gender) {
                ForEach(Gender.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Text("Optional. Used for minor calorie and HR zone estimates; not required to create your plan.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            // Age range
            VStack(alignment: .leading, spacing: 8) {
                Text("Age Range")
                    .font(.subheadline)
                Menu {
                    Picker("Age Range", selection: $ageRange) {
                        ForEach(AgeRange.allCases) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                } label: {
                    HStack {
                        Text(ageRange.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(AtlasTheme.gradient.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                }
                Text("Used to tailor recovery and mobility guidance.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            // Height mode toggle
            Picker("Height units", selection: $heightMode) {
                ForEach(HeightMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: heightMode) { _, newValue in
                if newValue == .imperial {
                    // Convert cm -> ft/in
                    let totalInches = Int(round(heightInCm / 2.54))
                    feet = max(0, totalInches / 12)
                    inches = max(0, totalInches % 12)
                }
            }
            
            // Height input
            if heightMode == .cm {
                VStack(alignment: .leading) {
                    Text("Height (cm)").font(.subheadline)
                    TextField("Height", value: $heightInCm, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("Feet").font(.subheadline)
                        TextField("ft", value: $feet, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading) {
                        Text("Inches").font(.subheadline)
                        TextField("in", value: $inches, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .onChange(of: feet) { _, _ in updateCmFromImperial() }
                .onChange(of: inches) { _, _ in updateCmFromImperial() }
            }
            
            // Weight
            VStack(alignment: .leading) {
                Text("Weight").font(.subheadline)
                HStack {
                    TextField("Weight", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    Picker("", selection: $units) {
                        ForEach(Units.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .frame(width: 90)
                }
            }
        }
        .padding(16)
        .onAppear {
            // Initialize imperial fields from cm if user flips modes
            let totalInches = Int(round(heightInCm / 2.54))
            feet = max(0, totalInches / 12)
            inches = max(0, totalInches % 12)
        }
    }
    
    private func updateCmFromImperial() {
        let inchesClamped = max(0, min(inches, 11))
        let totalInches = max(0, feet) * 12 + inchesClamped
        heightInCm = Double(totalInches) * 2.54
    }
}

private struct SelectRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.headline).foregroundStyle(.primary)
                Spacer()
                if isSelected { Image(systemName: "checkmark.circle.fill") }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(AtlasTheme.gradient.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct PlanChoiceStep: View {
    let plan: WeeklyPlan
    @Binding var decision: OnboardingViewModel.PlanDecision?

    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kickstart your weekly plan")
                .font(.title2.bold())
                .gradientForeground()

            Text("Here’s how we’d structure your week based on what you told us.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if plan.days.isEmpty {
                Text("We'll remind you to build a plan later, or you can start from scratch now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(plan.days.keys.sorted(), id: \.self) { day in
                        let focus = plan.days[day]?.joined(separator: ", ") ?? "Rest"
                        HStack {
                            Text(label(for: day).uppercased())
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            Text(focus)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                }
                .padding(14)
                .background(AtlasTheme.gradient.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
            }

            VStack(spacing: 12) {
                PlanDecisionRow(
                    title: "Use AtlasFit’s recommended plan",
                    message: "Auto-fill my week so I can start training right away.",
                    icon: "sparkles",
                    isSelected: decision == .recommended
                ) { decision = .recommended }

                PlanDecisionRow(
                    title: "I’ll build my own plan",
                    message: "I’d rather customise each day myself in the planner.",
                    icon: "square.and.pencil",
                    isSelected: decision == .custom
                ) { decision = .custom }
            }

            Text("You can adjust your schedule anytime from the Weekly Planner tab.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private func label(for day: Int) -> String {
        let idx = (day - 1 + weekdaySymbols.count) % weekdaySymbols.count
        return weekdaySymbols[idx]
    }
}

private struct PlanDecisionRow: View {
    let title: String
    let message: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.white : .secondary)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AtlasTheme.neon)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AtlasTheme.gradient.opacity(isSelected ? 0.28 : 0.16))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview { OnboardingFlowView() }
