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

                        Stepper("Age: \(vm.age)", value: $vm.age, in: 13...100)

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
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { vm.save(); dismiss() }
                }
            }
            .alert("Heads up", isPresented: .constant(vm.alertMessage != nil), actions: {
                Button("OK") { vm.alertMessage = nil }
            }, message: {
                Text(vm.alertMessage ?? "")
            })
        }
    }
}

#Preview { EditProfileView() }
