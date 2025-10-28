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
            }
        }
        .highPriorityGesture(tabSwipeGesture)
        .onAppear {
            hideTabBar = (selected == .workout) && isWorkoutLogging
        }
        .onChange(of: selected) { newValue in
            if newValue != .workout {
                isWorkoutLogging = false
                hideTabBar = false
            } else {
                hideTabBar = isWorkoutLogging
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
            VStack(spacing: 16) {
                SectionHeader(title: "Settings", subtitle: "Personalize REPS")
                NavigationLink("Edit Profile") { EditProfileView() }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Light") { AtlasTabRoot().preferredColorScheme(.light) }
#Preview("Dark")  { AtlasTabRoot().preferredColorScheme(.dark) }
