import Foundation

struct WorkoutDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let area: FitnessArea
    let minimumExperience: TrainingExperience
    let equipment: String
    let summary: String

    init(name: String, area: FitnessArea, minimumExperience: TrainingExperience = .novice, equipment: String, summary: String) {
        self.name = name
        self.area = area
        self.minimumExperience = minimumExperience
        self.equipment = equipment
        self.summary = summary
        self.id = WorkoutDefinition.makeID(name: name, area: area)
    }

    private static func makeID(name: String, area: FitnessArea) -> String {
        let cleaned = name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(area.rawValue.lowercased())-\(cleaned)"
    }
}

final class WorkoutCatalog {
    static let shared = WorkoutCatalog()

    let all: [WorkoutDefinition]
    private let lookup: [String: WorkoutDefinition]
    private let grouped: [FitnessArea: [WorkoutDefinition]]

    private init() {
        let definitions: [WorkoutDefinition] = [
            // Strength
            WorkoutDefinition(
                name: "Bench Press",
                area: .strength,
                minimumExperience: .intermediate,
                equipment: "Barbell or dumbbells",
                summary: "3 sets of 6-8 reps building upper-body pushing strength."
            ),
            WorkoutDefinition(
                name: "Incline Dumbbell Press",
                area: .strength,
                minimumExperience: .intermediate,
                equipment: "Bench + dumbbells",
                summary: "Angle the bench 30° for 10-12 controlled reps targeting upper chest."
            ),
            WorkoutDefinition(
                name: "Push-Ups",
                area: .strength,
                minimumExperience: .novice,
                equipment: "Bodyweight",
                summary: "2-3 sets to comfortable fatigue keeping a strong plank line."
            ),
            WorkoutDefinition(
                name: "Single-Arm Dumbbell Row",
                area: .strength,
                minimumExperience: .novice,
                equipment: "Dumbbell + bench",
                summary: "3 sets of 8-10 per arm focusing on squeezing the back."
            ),
            WorkoutDefinition(
                name: "Lat Pulldown",
                area: .strength,
                minimumExperience: .novice,
                equipment: "Cable machine",
                summary: "Keep core tight for 3 sets of 10-12 reps drawing elbows toward ribs."
            ),
            WorkoutDefinition(
                name: "Goblet Squat",
                area: .strength,
                minimumExperience: .novice,
                equipment: "Dumbbell or kettlebell",
                summary: "Sit tall for 3 sets of 10 reps to build leg strength and posture."
            ),
            WorkoutDefinition(
                name: "Romanian Deadlift",
                area: .strength,
                minimumExperience: .intermediate,
                equipment: "Barbell or dumbbells",
                summary: "3 sets of 8 reps hinging at the hips to target hamstrings and glutes."
            ),
            WorkoutDefinition(
                name: "Walking Lunge",
                area: .strength,
                minimumExperience: .novice,
                equipment: "Bodyweight or light dumbbells",
                summary: "Perform 3 x 12 steps per leg for balance and single-leg strength."
            ),
            WorkoutDefinition(
                name: "Seated Shoulder Press",
                area: .strength,
                minimumExperience: .novice,
                equipment: "Dumbbells",
                summary: "3 sets of 8-10 reps keeping ribs down and shoulders strong."
            ),
            WorkoutDefinition(
                name: "Cable Triceps Pressdown",
                area: .strength,
                minimumExperience: .novice,
                equipment: "Cable machine",
                summary: "3 x 12 reps with elbows close to your sides for arm definition."
            ),
            WorkoutDefinition(
                name: "Hammer Curl",
                area: .strength,
                minimumExperience: .novice,
                equipment: "Dumbbells",
                summary: "3 x 12 reps using a neutral grip to build forearm and biceps strength."
            ),

            // Mobility
            WorkoutDefinition(
                name: "Cat-Cow Flow",
                area: .mobility,
                minimumExperience: .novice,
                equipment: "Yoga mat",
                summary: "Move through 10 gentle reps to warm up the spine and core."
            ),
            WorkoutDefinition(
                name: "World's Greatest Stretch",
                area: .mobility,
                minimumExperience: .novice,
                equipment: "Bodyweight",
                summary: "Alternate sides for 6 slow reps to open hips, hamstrings and thoracic spine."
            ),
            WorkoutDefinition(
                name: "Hip Flexor Stretch",
                area: .mobility,
                minimumExperience: .novice,
                equipment: "Mat or pad",
                summary: "Hold each side 30 seconds to ease desk-tight hips."
            ),
            WorkoutDefinition(
                name: "90/90 Hip Switch",
                area: .mobility,
                minimumExperience: .novice,
                equipment: "Bodyweight",
                summary: "Perform 8 controlled switches keeping torso tall for hip rotation."
            ),
            WorkoutDefinition(
                name: "Thoracic Spine Opener",
                area: .mobility,
                minimumExperience: .novice,
                equipment: "Foam roller",
                summary: "Roll upper back for 90 seconds, pausing on sticky spots."
            ),
            WorkoutDefinition(
                name: "Child's Pose Breathing",
                area: .mobility,
                minimumExperience: .novice,
                equipment: "Yoga mat",
                summary: "3 deep-breath rounds to relax shoulders and lower back."
            ),

            // Power
            WorkoutDefinition(
                name: "Kettlebell Swing",
                area: .power,
                minimumExperience: .intermediate,
                equipment: "Kettlebell",
                summary: "3 sets of 15 explosive swings driving hips forward."
            ),
            WorkoutDefinition(
                name: "Medicine Ball Slam",
                area: .power,
                minimumExperience: .novice,
                equipment: "Medicine ball",
                summary: "3 x 12 slams focusing on speed and full-body power."
            ),
            WorkoutDefinition(
                name: "Jump Squat",
                area: .power,
                minimumExperience: .intermediate,
                equipment: "Bodyweight",
                summary: "3 sets of 10 soft landings to train quick lower-body drive."
            ),
            WorkoutDefinition(
                name: "Box Jump",
                area: .power,
                minimumExperience: .intermediate,
                equipment: "Plyo box",
                summary: "5 sets of 5 crisp jumps emphasizing stick-stable landings."
            ),
            WorkoutDefinition(
                name: "Push Press",
                area: .power,
                minimumExperience: .intermediate,
                equipment: "Barbell or dumbbells",
                summary: "4 sets of 6 explosive presses using a slight knee drive."
            ),

            // Quick intervals (HIIT)
            WorkoutDefinition(
                name: "Treadmill Sprint Intervals",
                area: .hiit,
                minimumExperience: .intermediate,
                equipment: "Treadmill",
                summary: "8 rounds of 30s fast / 60s easy running for high-intensity cardio."
            ),
            WorkoutDefinition(
                name: "Bike Tabata",
                area: .hiit,
                minimumExperience: .intermediate,
                equipment: "Stationary bike",
                summary: "8 cycles of 20s all-out pedaling with 10s recovery between efforts."
            ),
            WorkoutDefinition(
                name: "Rowing Machine Bursts",
                area: .hiit,
                minimumExperience: .intermediate,
                equipment: "Rowing machine",
                summary: "10 x 200m powerful pulls with easy strokes to recover."
            ),
            WorkoutDefinition(
                name: "Jump Rope Sprint Ladder",
                area: .hiit,
                minimumExperience: .novice,
                equipment: "Jump rope",
                summary: "5-minute ladder alternating 30s fast jumps with 30s brisk marching."
            ),
            WorkoutDefinition(
                name: "Bodyweight Power Circuit",
                area: .hiit,
                minimumExperience: .novice,
                equipment: "Mat + timer",
                summary: "3 rounds of squats, mountain climbers, and skaters for 40s on / 20s off."
            ),

            // Steady cardio (NEAT/LISS)
            WorkoutDefinition(
                name: "Brisk Outdoor Walk",
                area: .neat,
                minimumExperience: .novice,
                equipment: "Comfortable shoes",
                summary: "30-40 minutes at a pace that elevates heart rate but allows conversation."
            ),
            WorkoutDefinition(
                name: "Easy Cycling",
                area: .neat,
                minimumExperience: .novice,
                equipment: "Bike or spin bike",
                summary: "35 minutes of smooth pedaling in zone 2 heart-rate effort."
            ),
            WorkoutDefinition(
                name: "Light Jog",
                area: .neat,
                minimumExperience: .novice,
                equipment: "Running shoes",
                summary: "25 minutes of easy running focusing on relaxed breathing."
            ),
            WorkoutDefinition(
                name: "Elliptical Cruise",
                area: .neat,
                minimumExperience: .novice,
                equipment: "Elliptical trainer",
                summary: "30 minutes steady with light resistance to boost daily movement."
            ),
            WorkoutDefinition(
                name: "Stair Climb Steady Pace",
                area: .neat,
                minimumExperience: .intermediate,
                equipment: "Stair machine or stadium steps",
                summary: "20-25 minutes continuous climbing at a controlled pace."
            )
        ]

        self.all = definitions
        self.lookup = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
        var grouped: [FitnessArea: [WorkoutDefinition]] = Dictionary(grouping: definitions, by: { $0.area })
        for area in FitnessArea.allCases where grouped[area] == nil {
            grouped[area] = []
        }
        self.grouped = grouped
    }

    func workout(for id: String) -> WorkoutDefinition? {
        lookup[id]
    }

    func workouts(forIDs ids: [String]) -> [WorkoutDefinition] {
        ids.compactMap { lookup[$0] }
    }

    func sampleWorkouts(for area: FitnessArea, experience: TrainingExperience, count: Int, excluding existing: Set<String> = []) -> [WorkoutDefinition] {
        guard count > 0 else { return [] }
        let eligible = grouped[area, default: []].filter { $0.minimumExperience.levelIndex <= experience.levelIndex }
        guard !eligible.isEmpty else { return [] }

        let sorted = eligible.sorted { lhs, rhs in
            if lhs.minimumExperience.levelIndex == rhs.minimumExperience.levelIndex {
                return lhs.name < rhs.name
            }
            return lhs.minimumExperience.levelIndex < rhs.minimumExperience.levelIndex
        }

        var used = existing
        var picks: [WorkoutDefinition] = []
        for workout in sorted where picks.count < count {
            if used.contains(workout.id) { continue }
            picks.append(workout)
            used.insert(workout.id)
        }

        if picks.count < count {
            var index = 0
            while picks.count < count && index < sorted.count {
                let candidate = sorted[index]
                if !picks.contains(candidate) {
                    picks.append(candidate)
                }
                index += 1
            }
        }

        return picks
    }

    func allWorkouts(for area: FitnessArea? = nil, experience: TrainingExperience? = nil) -> [WorkoutDefinition] {
        var source = area.map { grouped[$0] ?? [] } ?? all
        if let experience {
            source = source.filter { $0.minimumExperience.levelIndex <= experience.levelIndex }
        }
        return source.sorted { $0.name < $1.name }
    }
}
