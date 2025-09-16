//
//  AtlasUI.swift
//  AtlasFit
//

import SwiftUI

// MARK: - Theme

enum AtlasTheme {
    // Core palette
    static let sky = Color(red: 246.0/255.0, green: 249.0/255.0, blue: 253.0/255.0)
    static let mist = Color(red: 229.0/255.0, green: 236.0/255.0, blue: 247.0/255.0)
    static let pebble = Color(red: 210.0/255.0, green: 220.0/255.0, blue: 235.0/255.0)

    static var bgBase: Color { sky }
    static var bgElevated: Color { .white }

    static let neon = Color(red: 0.22, green: 0.55, blue: 0.96)      // energetic primary
    static let magenta = Color(red: 0.16, green: 0.75, blue: 0.72)   // balancing teal
    static let amber = Color(red: 0.99, green: 0.69, blue: 0.28)     // warm highlight

    static var canvas: LinearGradient {
        LinearGradient(colors: [Color.white, sky, mist],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    static var gradient: LinearGradient {
        LinearGradient(colors: [neon, magenta], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var gradientAlt: LinearGradient {
        LinearGradient(colors: [magenta, amber], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var cardFill: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.95), Color.white.opacity(0.7)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    static var border: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.8), pebble.opacity(0.35)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }
}

// MARK: - Helpers & Modifiers

extension View {
    func gradientForeground(_ gradient: LinearGradient = AtlasTheme.gradient) -> some View {
        overlay(gradient).mask(self)
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

// MARK: - Background

struct NeonMotionBackground: View {
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle()
                .fill(AtlasTheme.canvas)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [AtlasTheme.neon.opacity(0.28), .clear],
                        center: .topTrailing,
                        startRadius: 40,
                        endRadius: 360
                    )
                )
                .offset(x: animate ? 40 : -20, y: -160)
                .blur(radius: 120)
                .animation(reduceMotion ? nil : .easeInOut(duration: 20).repeatForever(autoreverses: true), value: animate)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [AtlasTheme.magenta.opacity(0.25), .clear],
                        center: .bottomLeading,
                        startRadius: 40,
                        endRadius: 320
                    )
                )
                .offset(x: animate ? -30 : 50, y: 220)
                .blur(radius: 140)
                .animation(reduceMotion ? nil : .easeInOut(duration: 24).repeatForever(autoreverses: true), value: animate)

            LinearGradient(colors: [Color.white.opacity(0.6), Color.clear], startPoint: .top, endPoint: .bottom)
                .blendMode(.screen)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}

// MARK: - Core Components

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
                    .strokeBorder(.white.opacity(0.12))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 8)
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
                    .overlay(Circle().strokeBorder(AtlasTheme.gradient.opacity(0.6)))
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
