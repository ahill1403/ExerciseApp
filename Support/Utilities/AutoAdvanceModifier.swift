//
//  AutoAdvanceModifier.swift
//  REPS
//
//  Created by Aaron Hill on 10/27/25.
//

import SwiftUI

private struct AutoAdvanceModifier: ViewModifier {
    let seconds: Double
    let action: () -> Void
    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard seconds > 0 else { return }
                task?.cancel()
                task = Task {
                    let ns = UInt64(seconds * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: ns)
                    guard !Task.isCancelled else { return }
                    action()
                }
            }
            .onDisappear {
                task?.cancel()
                task = nil
            }
    }
}

extension View {
    /// Auto-runs `action` after `seconds`. Cancels on disappear.
    func autoAdvance(after seconds: Double, perform action: @escaping () -> Void) -> some View {
        modifier(AutoAdvanceModifier(seconds: seconds, action: action))
    }
}
