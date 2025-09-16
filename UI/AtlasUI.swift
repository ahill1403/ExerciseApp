//
//  AtlasUI.swift
//  AtlasFit
//

import SwiftUI

// MARK: - Theme

enum AtlasTheme {
static var bgBase: Color { Color(uiColor: .systemBackground) }
static var bgElevated: Color { Color(uiColor: .secondarySystemBackground) }

static let neon = Color(hue: 0.56, saturation: 0.85, brightness: 0.95)
static let magenta = Color(hue: 0.86, saturation: 0.80, brightness: 0.95)
static let amber = Color(hue: 0.08, saturation: 0.85, brightness: 1.0)

static var canvas: LinearGradient {
LinearGradient(colors: [bgBase, bgElevated], startPoint: .topLeading, endPoint: .bottomTrailing)
}
static var gradient: LinearGradient {
LinearGradient(colors: [neon, magenta], startPoint: .topLeading, endPoint: .bottomTrailing)
}
static var gradientAlt: LinearGradient {
LinearGradient(colors: [amber, neon], startPoint: .top, endPoint: .bottomTrailing)
}
}

// MARK: - Helpers & Modifiers

extension View {
func gradientForeground(_ gradient: LinearGradient = AtlasTheme.gradient) -> some View {
overlay(gradient).mask(self)
}

func glassCard(cornerRadius: CGFloat = 20) -> some View {
background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
.overlay(
RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
.strokeBorder(AtlasTheme.gradient.opacity(0.55), lineWidth: 1)
)
.shadow(color: AtlasTheme.neon.opacity(0.10), radius: 14, x: 0, y: 8)
}

func glow(_ color: Color, radius: CGFloat = 16) -> some View {
shadow(color: color.opacity(0.5), radius: radius, x: 0, y: 0)
.shadow(color: color.opacity(0.2), radius: radius * 1.5, x: 0, y: 0)
}
}

// MARK: - Background

struct NeonMotionBackground: View {
@State private var rotate = false
@Environment(\.accessibilityReduceMotion) private var reduceMotion

var body: some View {
ZStack {
AtlasTheme.canvas

AngularGradient(
gradient: Gradient(colors: [AtlasTheme.neon, AtlasTheme.magenta, AtlasTheme.amber, AtlasTheme.neon]),
center: .center
)
.blur(radius: 180)
.opacity(0.5)
.scaleEffect(1.35)
.rotationEffect(.degrees(rotate ? 360 : 0))
.animation(reduceMotion ? nil : .linear(duration: 60).repeatForever(autoreverses: false), value: rotate)
.blendMode(.screen)

RadialGradient(
colors: [Color.white.opacity(0.10), .clear],
center: .topLeading,
startRadius: 0,
endRadius: 600
)
.allowsHitTesting(false)
}
.ignoresSafeArea()
.onAppear { rotate = true }
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
            .glow(AtlasTheme.neon, radius: 10)
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
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().strokeBorder(AtlasTheme.gradient.opacity(0.7)))
            )
            .glow(AtlasTheme.magenta, radius: 6)
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
