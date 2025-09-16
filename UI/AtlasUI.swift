//
//  AtlasUI.swift
//  AtlasFit
//

import SwiftUI

// MARK: - Theme (Subtle Light Blue + Darker Blue Text)

enum AtlasTheme {
    // Background palette — very light, almost-white blues
    static let sky     = Color(red: 245/255, green: 249/255, blue: 254/255)   // #F5F9FE
    static let mist    = Color(red: 238/255, green: 244/255, blue: 252/255)   // #EEF4FC
    static let pebble  = Color(red: 220/255, green: 230/255, blue: 245/255)   // soft divider

    static var bgBase: Color { sky }      // app background
    static var bgElevated: Color { .white }

    // Brand blues (kept) + thematic text (slightly darker)
    static let bluePrimary   = Color(red: 0.17, green: 0.47, blue: 0.92)      // #2B78EB
    static let blueSecondary = Color(red: 0.13, green: 0.40, blue: 0.82)      // #2167D1
    static let blueMuted     = Color(red: 0.10, green: 0.30, blue: 0.62)      // #1A4D9E

    // NEW: thematic text color (darker, readable on light bg)
    static let textPrimary = Color(red: 0.10, green: 0.30, blue: 0.62)        // same as blueMuted

    // Back-compat aliases (ok to remove later)
    static let neon: Color    = bluePrimary
    static let magenta: Color = blueSecondary
    static let amber: Color   = blueMuted

    // Canvas: whisper-light blue wash (almost flat)
    static var canvas: LinearGradient {
        LinearGradient(
            colors: [Color.white, sky, mist],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Primary gradient for accents/text masking (now near-solid darker blue)
    static var gradient: LinearGradient {
        LinearGradient(
            colors: [
                textPrimary.opacity(0.98),
                blueSecondary.opacity(0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Alt gradient (slightly different hue, still subtle)
    static var gradientAlt: LinearGradient {
        LinearGradient(
            colors: [
                blueSecondary.opacity(0.96),
                bluePrimary.opacity(0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cardFill: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.96), Color.white.opacity(0.78)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var border: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.85), pebble.opacity(0.30)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Background tones

extension AtlasTheme {
    enum BackgroundTone: String {
        case light, medium, dark
    }

    // Subtle solid blues (tuned to stay calm)
    static let bgLight  = Color(red: 245/255, green: 249/255, blue: 254/255)  // very light
    static let bgMedium = Color(red: 230/255, green: 240/255, blue: 252/255)  // a bit richer
    static let bgDark   = Color(red: 210/255, green: 225/255, blue: 245/255)  // clearly darker, still soft

    static func bg(_ tone: BackgroundTone) -> Color {
        switch tone {
        case .light:  return bgLight
        case .medium: return bgMedium
        case .dark:   return bgDark
        }
    }
}


// MARK: - Helpers & Modifiers

extension View {
    func gradientForeground(_ gradient: LinearGradient = AtlasTheme.gradient) -> some View {
        overlay(gradient).mask(self)
    }

    // NEW: use when you want “thematic” blue text without a gradient
    func thematicForeground() -> some View {
        foregroundStyle(AtlasTheme.textPrimary)
    }

    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AtlasTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(AtlasTheme.border, lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
    }

    func glow(_ color: Color, radius: CGFloat = 16) -> some View {
        shadow(color: color.opacity(0.22), radius: radius, x: 0, y: radius * 0.25)
    }
}

// MARK: - Background (solid)

struct NeonMotionBackground: View {
    var body: some View {
        Rectangle()
            .fill(AtlasTheme.bgDark)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

// MARK: - Core Components (unchanged)
struct AtlasButtonStyle: ButtonStyle {
    var gradient: LinearGradient = AtlasTheme.gradient
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.10))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 8)
    }
}

struct AtlasBadge: View {
    let systemName: String
    var body: some View {
        Image(systemName: systemName)
            .font(.title2.weight(.semibold))
            .padding(12)
            .background(
                Circle()
                    .fill(AtlasTheme.cardFill)
                    .overlay(
                        Circle().strokeBorder(
                            LinearGradient(
                                colors: [
                                    AtlasTheme.bluePrimary.opacity(0.35),
                                    AtlasTheme.blueSecondary.opacity(0.35)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    )
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String?
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
                Text(title).font(.title.bold())
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Layout Utilities (shared)

public struct Wrap<Content: View>: View {
    var spacing: CGFloat
    private let content: () -> Content

    public init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        FlowLayout(spacing: spacing, content: content)
    }
}

public struct FlowLayout<Content: View>: View {
    var spacing: CGFloat
    private let content: () -> Content

    public init(spacing: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        GeometryReader { geo in
            _FlowLayout(spacing: spacing, width: geo.size.width, content: content())
        }
        .frame(minHeight: 0)
    }
}

private struct _FlowLayout<Content: View>: View {
    var spacing: CGFloat
    var width: CGFloat
    let content: Content

    var body: some View {
        var x: CGFloat = 0
        var y: CGFloat = 0

        return ZStack(alignment: .topLeading) {
            content
                .fixedSize()
                .alignmentGuide(.leading) { d in
                    if x + d.width > width {
                        x = 0
                        y -= d.height + spacing
                    }
                    let result = x
                    x += d.width + spacing
                    return result
                }
                .alignmentGuide(.top) { _ in y }
        }
    }
}

#Preview {
    ContentView()
}
