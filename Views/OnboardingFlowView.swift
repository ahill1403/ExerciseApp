import SwiftUI

struct OnboardingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.atlasMotion) private var motion
    @StateObject private var vm = OnboardingViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var didFinalize = false

    var body: some View {
        NavigationStack {
            ZStack {
                NeonMotionBackground()

                VStack(spacing: 16) {
                    let stepTransition: AnyTransition = motion.reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        )

                    // Progress: hide on .done to avoid out-of-bounds warning
                    if vm.step != .done {
                        let progress = vm.progress
                        ProgressView(value: progress.value, total: progress.total)
                            .progressViewStyle(.linear)
                            .tint(AtlasTheme.neon)
                            .padding(.horizontal, 20)
                            .scaleEffect(y: 1.6, anchor: .center)
                    }
                    
                    
                    ScrollView {
                        stepContent(for: vm.step)
                            .glassCard(cornerRadius: 24)
                            .padding(.horizontal, 20)
                            .padding(.top, 0)
                            .id(vm.step)
                            .transition(stepTransition)
                    }
                    .scrollIndicators(.hidden)
                    .animation(motion.primary, value: vm.step)
                    
                    VStack(spacing: 12) {
                        let title = vm.step == .plan ? "Finish" : "Continue"

                        // PRIMARY action (always in layout; fades out on .done)
                        Button(title) { vm.next() }
                            .buttonStyle(AtlasButtonStyle())
                            .disabled(vm.step == .done || !vm.canContinue)
                            .opacity(vm.step == .done ? 0 : 1)
                            .frame(maxWidth: .infinity)

                        // SECONDARY actions row (always in layout; fades out on .experience & .done)
                        let hideSecondary = (vm.step == .experience || vm.step == .done)

                        HStack(spacing: 12) {
                            Button("Back") { vm.back() }
                                .buttonStyle(AtlasButtonStyle(gradient: AtlasTheme.gradientAlt))
                                .frame(maxWidth: 180)

                            Button("Skip") { vm.skip() }
                                .buttonStyle(AtlasButtonStyle())
                                .frame(maxWidth: 180)
                        }
                        .opacity(hideSecondary ? 0 : 1)
                        .allowsHitTesting(!hideSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .animation(motion.relaxed, value: vm.step)
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
        }
        .onAppear {
            didFinalize = false
            NotificationCenter.default.post(name: .atlasTabBarVisibilityShouldHide, object: true)
        }
        .onDisappear {
            NotificationCenter.default.post(name: .atlasTabBarVisibilityShouldHide, object: false)
        }
    }
}

private extension OnboardingFlowView {
    @ViewBuilder
    func stepContent(for step: OnboardingViewModel.Step) -> some View {
        switch step {
        case .experience:
            ExperienceStep(experience: $vm.data.experience)
        case .goal:
            GoalStep(goal: $vm.data.goal)
        case .frequency:
            FrequencyStep(
                days: $vm.data.daysPerWeek,
                minutesPerDay: $vm.data.minutesPerDay,
                showMinutes: vm.data.experience != .beginner
            )
        case .reminder:
            ReminderStep(wants: $vm.data.wantsNotifications, time: $vm.data.reminderTime)
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
                if vm.data.experience == .beginner || vm.planDecision == .recommended {
                    Text("Your weekly plan is ready to go. Check it anytime under Planner.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Jump into the Weekly Planner to craft your own routine.")
                        .foregroundStyle(.secondary)
                }

                Button("Continue", action: finalizeOnboarding)
                    .buttonStyle(AtlasButtonStyle())
                    .padding(.top, 4)
            }
            .padding(16)
            .autoAdvance(
                after: AppConfig.Onboarding.completionHoldSeconds,
                perform: finalizeOnboarding
            )
            .padding(16)
        }
    }
}

private extension OnboardingFlowView {
    func finalizeOnboarding() {
        guard !didFinalize else { return }
        didFinalize = true
        hasCompletedOnboarding = true
        dismiss()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Training experience").font(.title2.bold()).gradientForeground()

            Text("Start with your overall comfort level.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(TrainingExperience.allCases) { e in
                SelectRow(title: e.rawValue, isSelected: experience == e) { experience = e }
            }

            Text("We’ll use this to tailor your workouts.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

private struct FrequencyStep: View {
    @Binding var days: Int
    @Binding var minutesPerDay: Int
    var showMinutes: Bool = true          // ← new

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your weekly rhythm").font(.title2.bold()).gradientForeground()

            Stepper("Days per week: \(days)", value: $days, in: 1...7)
                .padding(.vertical, 8)

            if showMinutes {               // ← wrap this section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time per day")
                        .font(.headline)
                    Stepper("\(minutesPerDay) minutes", value: $minutesPerDay, in: 10...180, step: 5)
                    Text("Helps size workouts to fit your schedule.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
    
    @State private var heightMode: HeightMode
    @State private var feet: Int
    @State private var inches: Int
    
    enum HeightMode: String, CaseIterable, Identifiable { case cm = "cm", imperial = "ft/in"; var id: String { rawValue } }
    
    init(
        gender: Binding<Gender>,
        ageRange: Binding<AgeRange>,
        heightInCm: Binding<Double>,
        weight: Binding<Double>,
        units: Binding<Units>
    ) {
        _gender = gender
        _ageRange = ageRange
        _heightInCm = heightInCm
        _weight = weight
        _units = units

        let totalInches = Int(round(heightInCm.wrappedValue / 2.54))
        _heightMode = State(initialValue: .imperial)
        _feet = State(initialValue: max(0, totalInches / 12))
        _inches = State(initialValue: max(0, totalInches % 12))
    }

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
            .background(
                AtlasTheme.gradient
                    .opacity(isSelected ? 0.26 : 0.18),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(isSelected ? 0.22 : 0.08))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.03 : 1)
        .shadow(color: AtlasTheme.accentGreen.opacity(isSelected ? 0.25 : 0), radius: isSelected ? 16 : 0, y: isSelected ? 8 : 0)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isSelected)
    }
}

private struct PlanChoiceStep: View {
    let plan: WeeklyPlan
    @Binding var decision: OnboardingViewModel.PlanDecision?

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
                WeekPlanGrid(plan: plan)
            }

            VStack(spacing: 12) {
                PlanDecisionRow(
                    title: "Use REPS’s recommended plan",
                    message: "Auto-fill my calendar with suggested workouts.",
                    icon: "sparkles",
                    isSelected: decision == .recommended
                ) { decision = .recommended }

                PlanDecisionRow(
                    title: "I’ll build my own plan",
                    message: "Let me start with a blank week and customise everything.",
                    icon: "square.and.pencil",
                    isSelected: decision == .custom
                ) { decision = .custom }
            }

            Text("You can adjust your schedule anytime from the Weekly Planner tab.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .onAppear {
            if decision == nil {
                decision = .recommended
            }
        }
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
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? AtlasTheme.accentGreen : .secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AtlasTheme.accentGreen, .white)
                }
            }
            .padding(16)
            .background(
                AtlasTheme.gradient
                    .opacity(isSelected ? 0.28 : 0.16),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.white.opacity(isSelected ? 0.24 : 0.1))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1)
        .shadow(color: AtlasTheme.accentGreen.opacity(isSelected ? 0.22 : 0), radius: isSelected ? 18 : 0, y: isSelected ? 10 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: isSelected)
    }
}

#Preview { OnboardingFlowView() }
