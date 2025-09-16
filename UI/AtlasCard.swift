//
//  AtlasCard.swift
//  AtlasFit
//
//  Created by Aaron Hill on 9/11/25.
//

import SwiftUI

struct AtlasCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var accent: Color = AtlasTheme.bluePrimary   // subtle blue default
    var centered: Bool = false                   // NEW

    var body: some View {
        Group {
            if centered {
                // Centered vertical layout
                VStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(
                            Circle().fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.92), accent.opacity(0.70)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        )
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.18)))
                        .glow(accent, radius: 10)

                    VStack(spacing: 4) {
                        Text(title).font(.headline)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
            } else {
                // Original horizontal layout
                HStack(spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(
                            Circle().fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.92), accent.opacity(0.70)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        )
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.18)))
                        .glow(accent, radius: 10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.headline)
                        Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
        }
        .glassCard(cornerRadius: 20)
        .contentShape(Rectangle())
    }
}
