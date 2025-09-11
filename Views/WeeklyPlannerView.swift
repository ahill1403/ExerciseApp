//
//  WeeklyPlannerView.swift
//  AtlasFit
//

import SwiftUI

struct WeeklyPlannerView: View {
    private let days = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
    private let areas = ["Mobility","Strength","Power","HIIT","NEAT/LISS"]

    var body: some View {
        NavigationStack {
            ZStack {
                NeonMotionBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Weekly Planner", subtitle: "Design your week")

                        // Legend (cosmetic only for now)
                        HStack(spacing: 8) {
                            ForEach(areas, id: \.self) { a in
                                LegendChip(text: a)
                            }
                        }

                        // Grid mock
                        VStack(spacing: 12) {
                            ForEach(days, id: \.self) { day in
                                PlannerRow(day: day, areas: areas)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Plan")
        }
    }
}

struct PlannerRow: View {
    let day: String
    let areas: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(day).font(.headline)
            Wrap {
                ForEach(areas, id: \.self) { a in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AtlasTheme.gradient.opacity(0.2))
                        .overlay(Text(a).font(.subheadline.weight(.semibold)))
                        .frame(height: 36)
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Small local chip for the legend

private struct LegendChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(AtlasTheme.gradient.opacity(0.25)))
    }
}

#Preview { WeeklyPlannerView() }
