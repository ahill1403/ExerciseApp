import SwiftUI

struct AtlasMotionPalette {
    let reduceMotion: Bool

    // Primary spring for major transitions.
    var primary: Animation {
        reduceMotion ? .easeInOut(duration: 0.22) : .spring(response: 0.46, dampingFraction: 0.86, blendDuration: 0.08)
    }

    // Relaxed spring for overlays / sheets that should feel softer.
    var relaxed: Animation {
        reduceMotion ? .easeInOut(duration: 0.26) : .spring(response: 0.5, dampingFraction: 0.88, blendDuration: 0.12)
    }

    // Micro interactions (button taps, quick toggles).
    var micro: Animation {
        .easeInOut(duration: reduceMotion ? 0.12 : 0.18)
    }

    // Crossfades between views / tab content.
    var crossfade: Animation {
        .easeInOut(duration: reduceMotion ? 0.18 : 0.32)
    }

    // Spring for tab selection / button emphasis.
    var selection: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.84, blendDuration: 0.06)
    }

    // Tab bar visibility / banner reveals.
    var elevated: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.48, dampingFraction: 0.88, blendDuration: 0.1)
    }

    var bannerTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)
    }

    var tabBarTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }
}

private struct AtlasMotionKey: EnvironmentKey {
    static let defaultValue = AtlasMotionPalette(reduceMotion: false)
}

extension EnvironmentValues {
    var atlasMotion: AtlasMotionPalette {
        get { self[AtlasMotionKey.self] }
        set { self[AtlasMotionKey.self] = newValue }
    }
}
