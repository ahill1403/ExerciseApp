//
//  HealthKitManager.swift
//  AtlasFit
//
//  Created by Aaron Hill on 9/13/25.
//

import Foundation
import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()
    
    func request() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set = [HKObjectType.workoutType()]
        let read: Set = [HKObjectType.workoutType(), HKObjectType.quantityType(forIdentifier: .bodyMass)!]
        try await store.requestAuthorization(toShare: share, read: read)
    }
    
    func save(_ session: WorkoutSession) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let start = session.date
        let end = session.duration.map { start.addingTimeInterval($0) } ?? start
        let workout = HKWorkout(activityType: .functionalStrengthTraining, start: start, end: end)
        try await store.save(workout)
    }
}
