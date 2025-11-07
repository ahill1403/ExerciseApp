//
//  AtlasTabRoot.swift
//  REPS
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Tabs

enum AtlasTab: Int, CaseIterable {
    case workout
    case planner
    case home
    case insights
    case settings
}

private struct TabSpec {
    let tab: AtlasTab
    let systemImage: String
    let accessibilityLabel: String
}

private let tabSpecs: [TabSpec] = [
    .init(tab: .workout,  systemImage: "dumbbell.fill",  accessibilityLabel: "Start Workout"),
    .init(tab: .planner,  systemImage: "calendar",        accessibilityLabel: "Weekly Planner"),
    .init(tab: .home,     systemImage: "house.fill",      accessibilityLabel: "Home"),
    .init(tab: .insights, systemImage: "chart.bar.xaxis", accessibilityLabel: "Progress"),
    .init(tab: .settings, systemImage: "gearshape",       accessibilityLabel: "Settings")
]

// MARK: - Root Shell

struct AtlasTabRoot: View {
    @State private var selected: AtlasTab = .home
    @State private var hideTabBar = false
    @State private var isWorkoutLogging = false

    var body: some View {
        ZStack {
            Group {
                switch selected {
                case .home:
                    NavigationStack { ContentView() }
                case .planner:
                    NavigationStack { WeeklyPlannerView() }
                case .workout:
                    NavigationStack { StartWorkoutView() }
                case .insights:
                    NavigationStack { ProgressDashboardView() }
                case .settings:
                    NavigationStack { SettingsHubView() }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !hideTabBar {
                AtlasTabBar(selected: $selected)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .highPriorityGesture(tabSwipeGesture)
        .onAppear {
            hideTabBar = (selected == .workout) && isWorkoutLogging
        }
        .onChange(of: selected) { newValue in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                if newValue != .workout {
                    isWorkoutLogging = false
                    hideTabBar = false
                } else {
                    hideTabBar = isWorkoutLogging
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .atlasLoggingStateChanged)) { note in
            guard let isLogging = note.object as? Bool else { return }
            isWorkoutLogging = isLogging
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                hideTabBar = (selected == .workout) && isLogging
            }
        }

    }
}

private extension AtlasTabRoot {
    var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.height) < 60 else { return }

                if value.translation.width < -70 {
                    moveToAdjacentTab(offset: 1)
                } else if value.translation.width > 70 {
                    moveToAdjacentTab(offset: -1)
                }
            }
    }

    func moveToAdjacentTab(offset: Int) {
        guard let currentIndex = AtlasTab.allCases.firstIndex(of: selected) else { return }
        let newIndex = currentIndex + offset

        guard (0..<AtlasTab.allCases.count).contains(newIndex) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            selected = AtlasTab.allCases[newIndex]
        }
    }
}

// MARK: - Bottom Bar

struct AtlasTabBar: View {
    @Environment(\.displayScale) private var scale
    @Binding var selected: AtlasTab

    var hairline: CGFloat { 1.0 / max(scale, 2) } // crisp

    private var bottomInset: CGFloat {
        #if canImport(UIKit)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.safeAreaInsets.bottom ?? 0
        #else
        return 0
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top divider (muted, scheme-aware)
            Rectangle()
                .fill(AtlasTheme.dividerColor)
                .frame(height: hairline)

            HStack {
                AtlasTabButton(spec: tabSpecs[0], selected: $selected)
                AtlasTabButton(spec: tabSpecs[1], selected: $selected)

                CenterHomeButton(isSelected: selected == .home) { selected = .home }

                AtlasTabButton(spec: tabSpecs[3], selected: $selected)
                AtlasTabButton(spec: tabSpecs[4], selected: $selected)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 5)
        }
        .background(
            // Subtle surface gradient to match cards/sheets
            LinearGradient(
                colors: [
                    AtlasTheme.bgElevated.opacity(0.90),
                    AtlasTheme.bgElevated.opacity(0.98)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.05), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(height: 50)
                    .frame(maxHeight: .infinity, alignment: .top)
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Buttons

private struct AtlasTabButton: View {
    let spec: TabSpec
    @Binding var selected: AtlasTab

    var isSelected: Bool { selected == spec.tab }

    var body: some View {
        Button {
            selected = spec.tab
        } label: {
            VStack(spacing: 0) {
                Image(systemName: spec.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .symbolVariant(isSelected ? .fill : .none)
                    .foregroundStyle(isSelected ? AtlasTheme.textPrimary : .secondary)
                    .frame(height: 24)

                // subtle active dot
                Circle()
                    .fill(isSelected ? AtlasTheme.gradient : LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 6, height: 6)
                    .opacity(isSelected ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .accessibilityLabel(spec.accessibilityLabel)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.06 : 1.0)
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isSelected)
    }
}

private struct CenterHomeButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AtlasTheme.gradient)
                    .frame(width: 56, height: 56)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.12)))
                    .glow(AtlasTheme.accentGreen, radius: 15)

                Image(systemName: "house.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Home")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Lightweight placeholders

struct SettingsHubView: View {
    var body: some View {
        ZStack {
            NeonMotionBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    SettingsSection(title: "Profile") {
                        NavigationLink {
                            EditProfileView()
                        } label: {
                            SettingsRow(
                                icon: "person.crop.circle",
                                iconTint: AtlasTheme.accentGreen,
                                title: "Profile",
                                subtitle: "Goals, schedule, and personal details"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsSection(title: "Workout") {
                        NavigationLink { UnitsSettingsView() } label: {
                            SettingsRow(
                                icon: "scalemass",
                                iconTint: Color.orange,
                                title: "Units",
                                subtitle: "Choose pounds or kilograms"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink { NotificationSettingsView() } label: {
                            SettingsRow(
                                icon: "bell.badge",
                                iconTint: AtlasTheme.accentGreen,
                                title: "Notifications",
                                subtitle: "Workout reminders and alerts"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink { IntegrationsSettingsView() } label: {
                            SettingsRow(
                                icon: "heart.fill",
                                iconTint: Color.red,
                                title: "Apple Health",
                                subtitle: "Connect workouts to Health"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsSection(title: "Support") {
                        NavigationLink { SupportSettingsView() } label: {
                            SettingsRow(
                                icon: "questionmark.circle",
                                iconTint: Color.blue,
                                title: "Help & Feedback",
                                subtitle: "Tips, FAQs, and contact options"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .safeAreaPadding(.bottom, 96)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                AtlasNavigationTitle(title: "Settings", subtitle: "Personalize REPS")
            }
        }
        .atlasNavigationBarStyle()
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)

            VStack(spacing: 12) {
                content
            }
        }
    }
}

private struct SettingsRow: View {
    var icon: String
    var iconTint: Color
    var title: String
    var subtitle: String?

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconTint.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconTint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AtlasTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AtlasTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AtlasTheme.border, lineWidth: 1)
        )
    }
}

#Preview("Light") { AtlasTabRoot().preferredColorScheme(.light) }
#Preview("Dark")  { AtlasTabRoot().preferredColorScheme(.dark) }
