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
    var accent: Color = AtlasTheme.neon

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .padding(12)
                .background(accent.opacity(0.9), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.15)))
                .glow(accent, radius: 6)

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
        .glassCard(cornerRadius: 20)
    }
}
