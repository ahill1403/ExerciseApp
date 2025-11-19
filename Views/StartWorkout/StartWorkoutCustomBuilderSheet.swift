import SwiftUI

struct CustomWorkoutBuilderSheet: View {
    @State private var searchText = ""
    @State private var selectedTarget: String?
    @State private var selectedEquipment: String?
    @State private var selections: Set<String>

    var onStart: ([WorkoutDefinition]) -> Void

    @Environment(\.dismiss) private var dismiss

    init(selectedWorkouts: [WorkoutDefinition], onStart: @escaping ([WorkoutDefinition]) -> Void) {
        self.onStart = onStart
        _selections = State(initialValue: Set(selectedWorkouts.map(\.id)))
    }

    private var allWorkouts: [WorkoutDefinition] { WorkoutCatalog.shared.all }

    private var equipmentOptions: [String] { ["Home", "Gym", "Running Shoes"] }

    private var targetMuscleOptions: [String] {
        Array(Set(allWorkouts.flatMap { $0.targetMuscles.map { $0.capitalized } })).sorted()
    }

    private var filteredWorkouts: [WorkoutDefinition] {
        let searchTerm = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allWorkouts.filter { workout in
            let matchesTarget = selectedTarget.map { target in
                workout.targetMuscles.contains { $0.lowercased() == target.lowercased() }
            } ?? true
            let matchesEquipment = selectedEquipment == nil || workout.equipmentCategory == selectedEquipment
            let matchesSearch = searchTerm.isEmpty
                || workout.name.lowercased().contains(searchTerm)
                || workout.summary.lowercased().contains(searchTerm)
                || workout.targetMuscles.contains { $0.lowercased().contains(searchTerm) }

            return matchesTarget && matchesEquipment && matchesSearch
        }
        .sorted { $0.name < $1.name }
    }

    private var selectedWorkouts: [WorkoutDefinition] {
        allWorkouts.filter { selections.contains($0.id) }.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Pick the exercises you want to log. You can still add or remove items once the session starts.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TemplateSearchField(text: $searchText, placeholder: "Search workouts or muscles")

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Target muscle")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                FilterChip(title: "All", isSelected: selectedTarget == nil) {
                                    selectedTarget = nil
                                }
                                ForEach(targetMuscleOptions, id: \.self) { muscle in
                                    FilterChip(title: muscle, isSelected: selectedTarget == muscle) {
                                        selectedTarget = selectedTarget == muscle ? nil : muscle
                                    }
                                }
                            }
                        }
                    }

                    TemplateFilters(
                        equipmentOptions: equipmentOptions,
                        durationOptions: [],
                        focusOptions: [],
                        selectedEquipment: $selectedEquipment,
                        selectedDuration: .constant(nil),
                        selectedFocus: .constant(nil)
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Exercises")
                            .font(.headline)
                        if filteredWorkouts.isEmpty {
                            Text("No exercises match your filters yet.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredWorkouts) { workout in
                                    Button {
                                        if selections.contains(workout.id) {
                                            selections.remove(workout.id)
                                        } else {
                                            selections.insert(workout.id)
                                        }
                                    } label: {
                                        HStack(alignment: .top, spacing: 12) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(workout.name)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundColor(AtlasTheme.textPrimary)
                                                Text(workout.summary)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text(workout.equipmentCategory)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer(minLength: 0)
                                            Image(systemName: selections.contains(workout.id) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selections.contains(workout.id) ? AtlasTheme.accentGreen : .secondary)
                                        }
                                        .padding(14)
                                        .background(AtlasTheme.cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(
                                                    selections.contains(workout.id)
                                                    ? AnyShapeStyle(AtlasTheme.accentGreen.opacity(0.3))
                                                    : AnyShapeStyle(AtlasTheme.border),
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Button {
                        onStart(selectedWorkouts)
                        dismiss()
                    } label: {
                        Label("Start custom session", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AtlasButtonStyle())
                }
                .padding(20)
            }
            .navigationTitle("Build your own")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .onAppear {
            searchText = ""
            selectedTarget = nil
            selectedEquipment = nil
        }
    }
}
