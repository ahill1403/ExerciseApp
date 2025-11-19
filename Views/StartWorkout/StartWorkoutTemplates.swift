import SwiftUI

struct TemplatePickerSheet: View {
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

    private let equipmentOptions: [String] = ["Home", "Gym", "Running Shoes"]

    private let durationOptions: [String] = ["20-30 mins", "30-40 mins", "40-50 mins", "50-60 mins"]

    private let focusOptions: [String] = ["Push", "Pull", "Legs", "Strength", "Power", "HIIT", "NEAT/LISS", "Mobility"]

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

struct TemplateSearchField: View {
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

struct TemplateFilters: View {
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

struct FilterSection: View {
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

struct FilterChip: View {
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

struct TemplateCard: View {
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

struct EncouragementBanner: View {
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
