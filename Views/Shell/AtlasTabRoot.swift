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
    .init(tab: .workout,  systemImage: "flag.checkered",  accessibilityLabel: "Start Workout"),
    .init(tab: .planner,  systemImage: "calendar",        accessibilityLabel: "Weekly Planner"),
    .init(tab: .home,     systemImage: "house.fill",      accessibilityLabel: "Home"),
    .init(tab: .insights, systemImage: "chart.bar.xaxis", accessibilityLabel: "Progress"),
    .init(tab: .settings, systemImage: "gearshape",       accessibilityLabel: "Settings")
]

// MARK: - Root Shell

struct AtlasTabRoot: View {
    @Environment(\.atlasMotion) private var motion
    @AppStorage("atlas.selectedTab") private var storedTabRawValue: Int = AtlasTab.home.rawValue

    @State private var selected: AtlasTab
    @State private var hideTabBar = false
    @State private var isWorkoutLogging = false
    @State private var isTabBarExternallyHidden = false
    @State private var tabBarHeight: CGFloat = 0

    init() {
        if let raw = UserDefaults.standard.object(forKey: "atlas.selectedTab") as? Int,
           let tab = AtlasTab(rawValue: raw) {
            _selected = State(initialValue: tab)
        } else {
            _selected = State(initialValue: .home)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .environment(\.atlasTabBarHeight, hideTabBar ? 0 : tabBarHeight)

            if !hideTabBar {
                AtlasTabBar(selected: $selected)
                    .transition(motion.tabBarTransition)
                    .zIndex(1)
            }
        }
        .onPreferenceChange(TabBarHeightPreferenceKey.self) { tabBarHeight = $0 }
        .highPriorityGesture(tabSwipeGesture)
        .onAppear {
            hideTabBar = shouldHideTabBar(for: selected)
            storedTabRawValue = selected.rawValue
        }
        .onChange(of: selected) { _, newValue in
            storedTabRawValue = newValue.rawValue
            if newValue != .workout { isWorkoutLogging = false }
            withAnimation(motion.elevated) {
                hideTabBar = shouldHideTabBar(for: newValue)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .atlasLoggingStateChanged)) { note in
            guard let isLogging = note.object as? Bool else { return }
            isWorkoutLogging = isLogging
            withAnimation(motion.elevated) {
                hideTabBar = shouldHideTabBar(for: selected)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .atlasTabBarVisibilityShouldHide)) { note in
            guard let shouldHide = note.object as? Bool else { return }
            isTabBarExternallyHidden = shouldHide
            withAnimation(motion.elevated) {
                hideTabBar = shouldHideTabBar(for: selected)
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }

    @ViewBuilder
    private var tabContent: some View {
        ZStack {
            TabContainer(tab: .home, selected: selected) {
                NavigationStack { ContentView() }
            }

            TabContainer(tab: .planner, selected: selected) {
                NavigationStack { WeeklyPlannerView() }
            }

            TabContainer(tab: .workout, selected: selected) {
                NavigationStack { StartWorkoutView() }
            }

            TabContainer(tab: .insights, selected: selected) {
                NavigationStack { ProgressDashboardView() }
            }

            TabContainer(tab: .settings, selected: selected) {
                NavigationStack { SettingsHubView() }
            }
        }
        .animation(motion.crossfade, value: selected)
    }

    private var tabSwipeGesture: some Gesture {
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

    private func moveToAdjacentTab(offset: Int) {
        guard let currentIndex = AtlasTab.allCases.firstIndex(of: selected) else { return }
        let newIndex = currentIndex + offset

        guard (0..<AtlasTab.allCases.count).contains(newIndex) else { return }

        withAnimation(motion.micro) {
            selected = AtlasTab.allCases[newIndex]
        }
    }

    private func shouldHideTabBar(for tab: AtlasTab) -> Bool {
        if isTabBarExternallyHidden { return true }
        return tab == .workout && isWorkoutLogging
    }
}

private struct TabContainer<Content: View>: View {
    let tab: AtlasTab
    let selected: AtlasTab
    let content: () -> Content

    init(tab: AtlasTab, selected: AtlasTab, @ViewBuilder content: @escaping () -> Content) {
        self.tab = tab
        self.selected = selected
        self.content = content
    }

    var body: some View {
        content()
            .opacity(selected == tab ? 1 : 0)
            .allowsHitTesting(selected == tab)
            .accessibilityHidden(selected != tab)
            .zIndex(selected == tab ? 1 : 0)
    }
}

// MARK: - Bottom Bar

struct AtlasTabBar: View {
    @Environment(\.displayScale) private var scale
    @Binding var selected: AtlasTab

    private var hairline: CGFloat { 1.0 / max(scale, 2) }

    var body: some View {
        VStack(spacing: 0) {
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
            .padding(.bottom, 6)
        }
        .background(
            LinearGradient(
                colors: [
                    AtlasTheme.bgElevated.opacity(0.68),
                    AtlasTheme.bgElevated.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: TabBarHeightPreferenceKey.self,
                        value: proxy.size.height + proxy.safeAreaInsets.bottom
                    )
            }
        )
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Buttons

private struct AtlasTabButton: View {
    let spec: TabSpec
    @Binding var selected: AtlasTab
    @Environment(\.atlasMotion) private var motion

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
        .scaleEffect(motion.reduceMotion ? 1 : (isSelected ? 1.06 : 1.0))
        .animation(motion.selection, value: isSelected)
    }
}

private struct CenterHomeButton: View {
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.atlasMotion) private var motion

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
        .scaleEffect(motion.reduceMotion ? 1 : (isSelected ? 1.02 : 0.96))
        .shadow(color: AtlasTheme.accentGreen.opacity(isSelected ? 0.32 : 0.18), radius: isSelected ? 18 : 12, y: isSelected ? 12 : 6)
        .animation(motion.selection, value: isSelected)
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
                .tabBarAware()
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
    @State private var isVisible = false

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
        .shadow(color: iconTint.opacity(0.12), radius: 12, y: 6)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 14)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: isVisible)
        .onAppear { isVisible = true }
    }
}

#Preview("Light") { AtlasTabRoot().preferredColorScheme(.light) }
#Preview("Dark")  { AtlasTabRoot().preferredColorScheme(.dark) }
