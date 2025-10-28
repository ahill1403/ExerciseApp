//
//  AtlasCard.swift — Emerald & Pine (Light & Dark ready)
//  REPS
//

import SwiftUI

struct AtlasCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var accent: Color = AtlasTheme.accentGreen
    var centered: Bool = false

    var body: some View {
        Group {
            if centered {
                VStack(spacing: 12) {
                    iconBadge
                    titles(alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
            } else {
                HStack(spacing: 14) {
                    iconBadge
                    titles(alignment: .leading)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary) // dynamic
                }
                .padding(16)
            }
        }
        .glassCard(cornerRadius: 20)    // uses dynamic cardFill/border from AtlasTheme
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Subviews

    private var iconBadge: some View {
        Image(systemName: systemImage)
            .font(.title2.bold())
            .foregroundStyle(.white)
            .padding(12)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [
                            AtlasTheme.emerald.opacity(0.98),
                            accent.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .overlay(Circle().strokeBorder(
                LinearGradient(
                    colors: [ Color.white.opacity(0.18), Color.white.opacity(0.10) ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            ))
            .glow(accent, radius: 10)
    }

    @ViewBuilder
    private func titles(alignment: TextAlignment) -> some View {
        VStack(alignment: alignment == .center ? .center : .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AtlasTheme.textPrimary) // dynamic
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)             // dynamic
        }
        .multilineTextAlignment(alignment)
    }
}

#Preview("Light") {
    VStack(spacing: 16) {
        AtlasCard(title: "Upper Body", subtitle: "4 exercises • 45 min", systemImage: "figure.strengthtraining.traditional")
        AtlasCard(title: "Zone 2 Cardio", subtitle: "30 min @ 120–130 bpm", systemImage: "heart.fill", centered: true)
        AtlasCard(title: "Progress", subtitle: "This week: +8% volume", systemImage: "chart.bar.xaxis", accent: AtlasTheme.emerald)
    }
    .padding()
    .background(AtlasTheme.canvas.ignoresSafeArea())
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack(spacing: 16) {
        AtlasCard(title: "Upper Body", subtitle: "4 exercises • 45 min", systemImage: "figure.strengthtraining.traditional")
        AtlasCard(title: "Zone 2 Cardio", subtitle: "30 min @ 120–130 bpm", systemImage: "heart.fill", centered: true)
        AtlasCard(title: "Progress", subtitle: "This week: +8% volume", systemImage: "chart.bar.xaxis", accent: AtlasTheme.emerald)
    }
    .padding()
    .background(AtlasTheme.canvas.ignoresSafeArea())
    .preferredColorScheme(.dark)
}
