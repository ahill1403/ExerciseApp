//
//  OnboardingExperienceMatrixView.swift
//  REPS
//
//  Created by Aaron Hill on 9/23/25.
//

import SwiftUI

struct OnboardingExperienceMatrixView: View {
    @Binding var experienceByArea: [FitnessArea: TrainingExperience]

    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Experience by Area",
                          subtitle: "Help us tune volume & intensity")
            ForEach(FitnessArea.allCases) { area in
                HStack(spacing: 12) {
                    Text(area.displayName)
                        .frame(width: 110, alignment: .leading)
                        .font(.body.weight(.semibold))
                        .minimumScaleFactor(0.85)

                    Picker("", selection: Binding(
                        get: { experienceByArea[area, default: .beginner] },
                        set: { experienceByArea[area] = $0 }
                    )) {
                        ForEach(TrainingExperience.allCases) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
    }
}
