//
//  StartWorkoutView.swift
//  REPS
//
//  Created by Aaron Hill on 9/11/25.
//

import SwiftUI

struct StartWorkoutView: View {
    @Environment(\.atlasMotion) private var motion
    @StateObject private var vm = StartWorkoutViewModel()

    // UI state only used on the home screen
    @State private var planSnapshot: WeeklyPlan = PlannerStore.shared.load()
    @State private var expandedTemplateID: StartWorkoutViewModel.TemplateInfo.ID?
    @State private var showAllTemplates = false
    @State private var showTemplatePicker = false
    @State private var showCustomBuilder = false

    @State private var completionMessage: String?

    var body: some View {
        ZStack {
            NeonMotionBackground()

            let sessionTransition = motion.reduceMotion
                ? AnyTransition.opacity
                : AnyTransition.move(edge: .bottom).combined(with: .opacity)

            if !vm.isLogging {
                homeContent
                    .transition(sessionTransition)
            } else {
                WorkoutSessionView(vm: vm)
                    .transition(sessionTransition)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                AtlasNavigationTitle(
                    title: vm.isLogging ? "Workout Session" : "Start Workout",
                    subtitle: vm.isLogging ? "Log sets and reps" : "Choose the next session"
                )
            }
        }
        .atlasNavigationBarStyle()
        .onAppear {
            vm.refreshPlanSuggestion()
            planSnapshot = PlannerStore.shared.load()
            NotificationCenter.default.post(name: .atlasLoggingStateChanged, object: vm.isLogging)
        }
        .onChange(of: vm.planSuggestion?.day) { _, _ in
            // keep the planner peek in sync
            planSnapshot = PlannerStore.shared.load()
        }
        .overlay(alignment: .top) {
            if let message = completionMessage {
                EncouragementBanner(message: message)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .transition(motion.bannerTransition)
            }
        }
        .animation(motion.primary, value: completionMessage)
        .animation(motion.primary, value: vm.isLogging)
        .onChange(of: vm.isLogging) { _, isLogging in
            NotificationCenter.default.post(name: .atlasLoggingStateChanged, object: isLogging)

            if isLogging {
                withAnimation(motion.primary) { completionMessage = nil }
            } else if let message = vm.lastCompletionMessage, completionMessage != message {
                presentCompletionMessage(message)
            }
        }
        .onChange(of: vm.lastCompletionMessage) { _, message in
            guard vm.isLogging == false, let message else { return }
            if completionMessage != message {
                presentCompletionMessage(message)
            }
        }
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerSheet(
                templates: vm.templates,
                expandedTemplateID: $expandedTemplateID,
                showAllTemplates: $showAllTemplates,
                onStartTemplate: { name in
                    vm.start(template: name)
                    expandedTemplateID = nil
                    showTemplatePicker = false
                },
                onStartCustom: {
                    expandedTemplateID = nil
                    showTemplatePicker = false
                    DispatchQueue.main.async {
                        showCustomBuilder = true
                    }
                }
            )
        }
        .sheet(isPresented: $showCustomBuilder) {
            CustomWorkoutBuilderSheet(selectedWorkouts: []) { workouts in
                vm.startCustomSession(with: workouts)
                showCustomBuilder = false
            }
        }
    }
}

private extension StartWorkoutView {
    func presentCompletionMessage(_ message: String) {
        completionMessage = message

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(motion.relaxed) {
                completionMessage = nil
            }
            vm.lastCompletionMessage = nil
        }
    }
}
