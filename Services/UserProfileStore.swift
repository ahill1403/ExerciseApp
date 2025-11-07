import Foundation

enum UserProfileStore {
    private static let storageKey = "userProfile"

    static func load() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    static func save(_ profile: UserProfile) {
        guard let encoded = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    static func upsert(_ update: (inout UserProfile) -> Void) {
        var profile = load() ?? defaultProfile()
        update(&profile)
        save(profile)
    }

    private static func defaultProfile() -> UserProfile {
        UserProfile(
            createdAt: .now,
            goal: .general,
            experience: .beginner,
            experienceByArea: FitnessArea.defaultExperienceLevels,
            daysPerWeek: 3,
            minutesPerDay: 45,
            reminderTime: nil,
            gender: .other,
            ageRange: .midAdults,
            heightInCm: 175,
            weight: 170,
            units: .lbs
        )
    }
}
