//
//  AtlasUI.swift — Emerald & Pine (Light & Dark)
//  REPS
//

import SwiftUI
import UIKit

// MARK: - Theme (Emerald & Pine — traditional, professional, subtle gradients)

enum AtlasTheme {
    // Brand hues (fixed)
    static let pine        = Color(hex: "#0E3B2E")   // Primary
    static let emerald     = Color(hex: "#145E43")   // Secondary
    static let accentGreen = Color(hex: "#22A06B")   // Accent

    // Dynamic neutrals
    static let ink          = Color.dynamic(lightHex: "#0F172A", darkHex: "#E5E7EB")  // text on bg
    static let paper        = Color.dynamic(lightHex: "#F8FAF9", darkHex: "#0E1218")  // app base
    static let elevated     = Color.dynamic(lightHex: "#FFFFFF", darkHex: "#10151D")  // cards, sheets
    static let support      = Color.dynamic(lightHex: "#A1B5AB", darkHex: "#94A3B8")  // supporting text
    static let dividerColor = Color.dynamic(lightHex: "#E3EAE6", darkHex: "#1F2937")  // separators

    // Background tints (gentle)
    static let dew  = Color.dynamic(lightHex: "#F4F8F6", darkHex: "#0F141B")
    static let mist = Color.dynamic(lightHex: "#EEF5F1", darkHex: "#0F151C")

    // Public surfaces
    static var bgBase: Color     { paper }
    static var bgElevated: Color { elevated }

    // Typography
    static let textPrimary   = ink
    static let textSecondary = Color.dynamic(lightHex: "#145E43", darkHex: "#CBD5E1") // emerald-ish on light, slate on dark

    // Back-compat aliases (keep old references linking)
    static let neon: Color    = accentGreen
    static let magenta: Color = emerald
    static let amber: Color   = pine

    // Canvas: subtle single-direction gradient (adapts)
    static var canvas: LinearGradient {
        LinearGradient(
            colors: [
                Color.dynamic(lightHex: "#FFFFFF", darkHex: "#0B0F14"),
                paper,
                dew
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Primary accent gradient (works on light & dark)
    static var gradient: LinearGradient {
        LinearGradient(
            colors: [ emerald.opacity(0.98), accentGreen.opacity(0.96) ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // Alternate gradient (pine → emerald)
    static var gradientAlt: LinearGradient {
        LinearGradient(
            colors: [ pine.opacity(0.98), emerald.opacity(0.96) ],
            startPoint: .top, endPoint: .bottom
        )
    }

    // Card fill: lift on light / subtle gloss on dark
    static var cardFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.dynamic(lightHex: "#FFFFFF", lightAlpha: 0.96,
                              darkHex: "#FFFFFF",   darkAlpha: 0.06),
                Color.dynamic(lightHex: "#FFFFFF", lightAlpha: 0.80,
                              darkHex: "#FFFFFF",   darkAlpha: 0.03)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // Border: whisper highlight → divider
    static var border: LinearGradient {
        LinearGradient(
            colors: [
                Color.dynamic(lightHex: "#FFFFFF", lightAlpha: 0.85,
                              darkHex:  "#FFFFFF", darkAlpha: 0.10),
                Color.dynamic(lightHex: "#E3EAE6", lightAlpha: 0.50,
                              darkHex:  "#FFFFFF", darkAlpha: 0.04)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

// MARK: - Background tones (for sections & large blocks)

extension AtlasTheme {
    enum BackgroundTone: String { case light, medium, dark }

    static let bgLight  = paper
    static let bgMedium = mist
    static let bgDark   = Color.dynamic(lightHex: "#E6F0EA", darkHex: "#0D1218")

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
        .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 12)
    }

    func glow(_ color: Color, radius: CGFloat = 16) -> some View {
        shadow(color: color.opacity(0.22), radius: radius, x: 0, y: radius * 0.25)
    }
}

// MARK: - Background (solid) + Legacy aliases

// Legacy blue aliases to satisfy older references & linkers expecting stored vars
extension AtlasTheme {
    static var bluePrimary: Color   = accentGreen  // old primary blue → accent green
    static var blueSecondary: Color = emerald      // old secondary blue → deep emerald
    static var blueAccent: Color    = accentGreen
    static var primaryBlue: Color   = emerald
    static var brandBlue: Color     = emerald
}

struct NeonMotionBackground: View { // kept name for back-compat
    var body: some View {
        Rectangle()
            .fill(AtlasTheme.bgBase)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

// MARK: - Core Components

struct AtlasButtonStyle: ButtonStyle {
    var gradient: LinearGradient = AtlasTheme.gradient
    @Environment(\.atlasMotion) private var motion

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
            .scaleEffect(configuration.isPressed && !motion.reduceMotion ? 0.98 : 1)
            .animation(motion.micro, value: configuration.isPressed)
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
                                    AtlasTheme.accentGreen.opacity(0.35),
                                    AtlasTheme.emerald.opacity(0.35)
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
                Text(title).font(.title.bold()).foregroundStyle(AtlasTheme.textPrimary)
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 4)
    }
}

struct AtlasNavigationTitle: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.headline.weight(.semibold))
                .thematicForeground()
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, 4)
    }
}

extension View {
    func atlasNavigationBarStyle() -> some View {
        self
            .toolbarBackground(
                LinearGradient(
                    colors: [
                        AtlasTheme.bgElevated.opacity(0.68),
                        AtlasTheme.bgElevated.opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(nil, for: .navigationBar)
            .tint(AtlasTheme.accentGreen)
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

// MARK: - Hex + Dynamic Color helpers

fileprivate extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hex = hex.replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    static func dynamic(lightHex: String, darkHex: String) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? uiColor(hex: darkHex) : uiColor(hex: lightHex)
        })
    }

    static func dynamic(lightHex: String, lightAlpha: CGFloat,
                        darkHex: String, darkAlpha: CGFloat) -> Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return uiColor(hex: darkHex, alpha: darkAlpha)
            } else {
                return uiColor(hex: lightHex, alpha: lightAlpha)
            }
        })
    }
}

fileprivate func uiColor(hex: String, alpha: CGFloat = 1.0) -> UIColor {
    var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hex = hex.replacingOccurrences(of: "#", with: "")
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let r = CGFloat((int >> 16) & 0xFF) / 255.0
    let g = CGFloat((int >> 8) & 0xFF) / 255.0
    let b = CGFloat(int & 0xFF) / 255.0
    return UIColor(red: r, green: g, blue: b, alpha: alpha)
}

#Preview("Light") {
    ZStack {
        AtlasTheme.canvas.ignoresSafeArea()
        VStack(spacing: 16) {
            SectionHeader(title: "Log Workout", subtitle: "Today")
            Button {} label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .gradientForeground()
                        .frame(width: 18, height: 18)
                    Text("Start Session")
                        .foregroundStyle(.white)
                        .padding(.vertical, 2)
                }
            }
            .buttonStyle(AtlasButtonStyle())

            HStack(spacing: 12) {
                AtlasBadge(systemName: "figure.strengthtraining.traditional")
                AtlasBadge(systemName: "heart.fill")
                AtlasBadge(systemName: "chart.bar.xaxis")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("This Week")
                    .font(.headline)
                    .foregroundStyle(AtlasTheme.textPrimary)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AtlasTheme.cardFill)
                    .frame(height: 120)
                    .overlay(
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Volume").font(.subheadline).foregroundStyle(.secondary)
                                Text("18,450 kg").font(.title3.bold()).foregroundStyle(AtlasTheme.textPrimary)
                            }
                        }
                        .padding()
                    )
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AtlasTheme.border))
            }
        }
        .padding(20)
    }
    .background(AtlasTheme.bgBase)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        AtlasTheme.canvas.ignoresSafeArea()
        VStack(spacing: 16) {
            SectionHeader(title: "Log Workout", subtitle: "Today")
            Button {} label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .gradientForeground()
                        .frame(width: 18, height: 18)
                    Text("Start Session")
                        .foregroundStyle(.white)
                        .padding(.vertical, 2)
                }
            }
            .buttonStyle(AtlasButtonStyle())
            HStack(spacing: 12) {
                AtlasBadge(systemName: "figure.strengthtraining.traditional")
                AtlasBadge(systemName: "heart.fill")
                AtlasBadge(systemName: "chart.bar.xaxis")
            }
        }
        .padding(20)
    }
    .background(AtlasTheme.bgBase)
    .preferredColorScheme(.dark)
}
