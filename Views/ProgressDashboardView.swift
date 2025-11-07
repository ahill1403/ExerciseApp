//
//  ProgressDashboardView.swift
//  REPS
//
//  Created by Aaron Hill on 9/11/25.
//

import SwiftUI
import Charts

struct ProgressDashboardView: View {
    @StateObject private var vm = ProgressViewModel()
    @State private var selectedRange: ProgressRange = .weekly
    @State private var selectedMetric: ProgressMetric = .workouts

    var body: some View {
        ZStack { NeonMotionBackground() }
            .overlay(
                ScrollView {
                    VStack(spacing: 16) {
                        if let last = vm.lastWorkout {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("Last workout: \(last.formatted(date: .abbreviated, time: .shortened))")
                                Spacer()
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 12) {
                                    Text("Progress Overview")
                                        .font(.title3.bold())
                                        .gradientForeground()
                                    Spacer()
                                    Picker("Range", selection: $selectedRange) {
                                        ForEach(ProgressRange.allCases) { range in
                                            Text(range.pickerTitle).tag(range)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .labelsHidden()
                                    .frame(maxWidth: 220)
                                    .accessibilityLabel("Time range")
                                }

                                MetricPicker(selectedMetric: $selectedMetric)

                                ProgressMetricCard(
                                    metric: selectedMetric,
                                    data: vm.chartData(for: selectedMetric, range: selectedRange),
                                    units: vm.preferredUnits
                                )
                            }
                        }

                        // History
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Workouts").font(.title3.bold()).gradientForeground()
                            if vm.sessions.isEmpty {
                                VStack(spacing: 8) {
                                    Text("No workouts yet").font(.headline)
                                    Text("Start a session to see your progress.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(24)
                                .glassCard(cornerRadius: 20)
                            } else {
                                ForEach(vm.sessions.prefix(12)) { session in
                                    WorkoutRow(session: session)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .safeAreaPadding(.bottom, 160)
                }
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    AtlasNavigationTitle(title: "Progress", subtitle: "Track your streaks")
                }
            }
            .atlasNavigationBarStyle()
            .onAppear { vm.refresh() }
    }
}

// MARK: - Components

private struct WorkoutRow: View {
    let session: WorkoutSession
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .padding(10)
                .background(AtlasTheme.gradient.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(session.template).font(.headline)
                Text("\(session.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.totalSets) sets").font(.subheadline)
                if let d = session.duration { Text(timeString(d)).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 16)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let mins = Int(t / 60)
        let secs = Int(t.truncatingRemainder(dividingBy: 60))
        return String(format: "%dm %02ds", mins, secs)
    }
}

private struct MetricPicker: View {
    @Binding var selectedMetric: ProgressMetric

    var body: some View {
        HStack(spacing: 12) {
            ForEach(ProgressMetric.allCases) { metric in
                Button {
                    selectedMetric = metric
                } label: {
                    Image(systemName: metric.iconName)
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(selectedMetric == metric ? Color.white : AtlasTheme.textPrimary.opacity(0.7))
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selectedMetric == metric ? AtlasTheme.gradient : AtlasTheme.cardFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(selectedMetric == metric ? AtlasTheme.gradient : AtlasTheme.border, lineWidth: 1.2)
                        )
                        .shadow(color: selectedMetric == metric ? AtlasTheme.accentGreen.opacity(0.25) : .clear, radius: 10, x: 0, y: 6)
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(metric.title)
                .accessibilityAddTraits(selectedMetric == metric ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProgressMetricCard: View {
    let metric: ProgressMetric
    let data: [ProgressDataPoint]
    let units: Units

    private var maxDataValue: Double {
        data.map(\.value).max() ?? 0
    }

    private var yUpperBound: Double {
        let maxValue = maxDataValue
        return maxValue == 0 ? 1 : maxValue * 1.2
    }

    private var totalValue: Double {
        data.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.title)
                    .font(.headline)
                Spacer()
                Text(metric.summary(for: totalValue, units: units))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Chart(data) { point in
                BarMark(
                    x: .value("Period", point.label),
                    y: .value(metric.yAxisLabel(units: units), point.value)
                )
                .cornerRadius(6)
                .foregroundStyle(AtlasTheme.gradient)
                .annotation(position: .top, alignment: .center) {
                    Text(metric.formattedValue(point.value))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: data.map(\.label)) { value in
                    if let label = value.as(String.self) {
                        AxisValueLabel(label)
                    }
                }
            }
            .chartYScale(domain: 0...yUpperBound)
            .frame(height: 180)
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }
}
