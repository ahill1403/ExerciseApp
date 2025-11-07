//
//  EditProfileView.swift
//  REPS
//

import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = EditProfileViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                NeonMotionBackground()

                Form {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your profile")
                                .font(.title2.bold())
                                .gradientForeground()
                            Text("Update goals, schedule, and basics any time.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }

                    Section("Goal & Training") {
                        Picker("Goal", selection: $vm.goal) {
                            ForEach(FitnessGoal.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.navigationLink)

                        Picker("Experience", selection: $vm.experience) {
                            ForEach(TrainingExperience.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.navigationLink)

                        Stepper("Days per Week: \(vm.daysPerWeek)", value: $vm.daysPerWeek, in: 1...7)

                        Stepper("Minutes per Day: \(vm.minutesPerDay)", value: $vm.minutesPerDay, in: 10...180, step: 5)
                        Text("Helps us size workouts to the time you have available.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)

                    Section("Experience by Area") {
                        Text("Fine-tune how confident you feel in each pillar of fitness.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        ForEach(FitnessArea.allCases) { area in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(area.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Picker("Experience", selection: Binding(
                                    get: { vm.experienceByArea[area] ?? .beginner },
                                    set: { vm.experienceByArea[area] = $0 }
                                )) {
                                    ForEach(TrainingExperience.allCases) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(.vertical, 4)
                        }

                        Text("Advanced ratings let you skip or customize those areas in your plan.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)

                    Section("Reminders") {
                        Toggle("Enable workout reminders", isOn: $vm.wantsNotifications)
                        if vm.wantsNotifications {
                            DatePicker("Reminder time", selection: $vm.reminderTime, displayedComponents: .hourAndMinute)
                        }
                        Text("You can change notification permissions in iOS Settings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)

                    Section("Physique") {
                        Picker("Gender", selection: $vm.gender) {
                            ForEach(Gender.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        Picker("Age Range", selection: $vm.ageRange) {
                            ForEach(AgeRange.allCases) { Text($0.displayName).tag($0) }
                        }
                        .pickerStyle(.navigationLink)

                        VStack(alignment: .leading) {
                            Text("Height (cm)").font(.subheadline)
                            TextField("Height", value: $vm.heightInCm, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading) {
                            Text("Weight").font(.subheadline)
                            HStack {
                                TextField("Weight", value: $vm.weight, format: .number)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                Picker("", selection: $vm.units) {
                                    ForEach(Units.allCases) { Text($0.rawValue).tag($0) }
                                }
                                .frame(width: 90)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)

                    Section {
                        Button {
                            vm.save()
                            // Mirror weekly goal to keep Home stats aligned even if the VM wasn't updated yet.
                            UserDefaults.standard.set(vm.daysPerWeek, forKey: "weeklyGoal")
                            dismiss()
                        } label: {
                            Text("Save Changes").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AtlasButtonStyle())
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(.clear)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    AtlasNavigationTitle(title: "Edit Profile", subtitle: "Keep your plan in sync")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        vm.save()
                        UserDefaults.standard.set(vm.daysPerWeek, forKey: "weeklyGoal")
                        dismiss()
                    }
                    .font(.headline)
                }
            }
            .atlasNavigationBarStyle()
            .alert("Heads up",
                   isPresented: .constant(vm.alertMessage != nil),
                   actions: { Button("OK") { vm.alertMessage = nil } },
                   message: { Text(vm.alertMessage ?? "") })
        }
    }
}

#Preview { EditProfileView() }
