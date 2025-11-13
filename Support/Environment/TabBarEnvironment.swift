import SwiftUI

struct TabBarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TabBarHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var atlasTabBarHeight: CGFloat {
        get { self[TabBarHeightKey.self] }
        set { self[TabBarHeightKey.self] = newValue }
    }
}

private struct TabBarAwareModifier: ViewModifier {
    var extra: CGFloat
    @Environment(\.atlasTabBarHeight) private var tabBarHeight

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.bottom, max(0, tabBarHeight) + extra)
    }
}

extension View {
    func tabBarAware(extra: CGFloat = 0) -> some View {
        modifier(TabBarAwareModifier(extra: extra))
    }
}
