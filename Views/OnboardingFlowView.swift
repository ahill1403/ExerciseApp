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
                        let total = OnboardingViewModel.Step.physique.rawValue + 1 // visible steps
                        let value = min(vm.step.rawValue, OnboardingViewModel.Step.physique.rawValue) + 1
                        ProgressView(value: Double(value), total: Double(total))
                            .tint(AtlasTheme.neon)
                            .padding(.horizontal, 20)
                    }

                    Group {
                        switch vm.step {
                        case .goal: GoalStep(goal: $vm.data.goal)
                        case .experience: ExperienceStep(experience: $vm.data.experience)
                        case .frequency: FrequencyStep(days: $vm.data.daysPerWeek)
                        case .reminder: ReminderStep(wants: $vm.data.wantsNotifications, time: $vm.data.reminderTime)
                        case .physique:
                            PhysiqueStep(
                                gender: $vm.data.gender,
                                age: $vm.data.age,
                                heightInCm: $vm.data.heightInCm,
                                weight: $vm.data.weight,
                                units: $vm.data.units
                            )
                        case .done:
                            VStack(spacing: 16) {
                                Text("You’re set!").font(.title.bold()).gradientForeground()
                                Text("Building your starting plan…").foregroundStyle(.secondary)
                            }
                            .padding(16)
                        }
                    }
                    .glassCard(cornerRadius: 24)
                    .padding(.horizontal, 20)

                    HStack(spacing: 12) {
                        if vm.step != .goal && vm.step != .done {
                            Button("Back") { vm.back() }
                                .buttonStyle(AtlasButtonStyle(gradient: AtlasTheme.gradientAlt))
                                .frame(maxWidth: 160)
                        }
                        if vm.step != .done {
                            Button("Continue") { vm.next() }
                                .buttonStyle(AtlasButtonStyle())
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
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Training experience").font(.title2.bold()).gradientForeground()
            ForEach(TrainingExperience.allCases) { e in
                SelectRow(title: e.rawValue, isSelected: experience == e) { experience = e }
            }
        }.padding(16)
    }
}

private struct FrequencyStep: View {
    @Binding var days: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How many days per week?").font(.title2.bold()).gradientForeground()
            Stepper("Days per week: \(days)", value: $days, in: 1...7)
                .padding(.vertical, 8)
            Text("You can refine your plan later in Weekly Planner.")
                .font(.subheadline).foregroundStyle(.secondary)
        }.padding(16)
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
    @Binding var age: Int
    @Binding var heightInCm: Double
    @Binding var weight: Double
    @Binding var units: Units

    @State private var heightMode: HeightMode = .cm
    @State private var feet: Int = 5
    @State private var inches: Int = 9
    @State private var showAgePicker = false

    enum HeightMode: String, CaseIterable, Identifiable { case cm = "cm", imperial = "ft/in"; var id: String { rawValue } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About you").font(.title2.bold()).gradientForeground()

            // Gender
            Picker("Gender", selection: $gender) {
                ForEach(Gender.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            // Age – wheel picker in a sheet
            Button {
                showAgePicker = true
            } label: {
                HStack {
                    Text("Age")
                    Spacer()
                    Text("\(age)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .padding(12)
                .background(AtlasTheme.gradient.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showAgePicker) {
                NavigationStack {
                    VStack {
                        Picker("Age", selection: $age) {
                            ForEach(13...100, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxHeight: 260)

                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Select Age")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showAgePicker = false }
                        }
                    }
                }
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

#Preview { OnboardingFlowView() }
