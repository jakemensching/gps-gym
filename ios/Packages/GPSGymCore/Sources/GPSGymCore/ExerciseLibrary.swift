import Foundation

/// Small, curated library. Within each pattern, entries are listed best-first
/// for a given equipment tier; the generator walks this order.
public enum ExerciseLibrary {
    private static func ex(
        _ id: String, _ name: String, _ pattern: MovementPattern, _ equipment: Equipment,
        compound: Bool = true, inc: Double
    ) -> Exercise {
        Exercise(id: id, name: name, pattern: pattern, equipment: equipment, isCompound: compound, loadIncrementLb: inc)
    }

    public static let all: [Exercise] = [
        // Squat
        ex("back-squat", "Barbell Back Squat", .squat, .fullGym, inc: 10),
        ex("leg-press", "Leg Press", .squat, .fullGym, inc: 10),
        ex("goblet-squat", "Goblet Squat", .squat, .dumbbells, inc: 5),
        ex("db-front-squat", "Dumbbell Front Squat", .squat, .dumbbells, inc: 5),
        ex("bw-squat", "Bodyweight Squat", .squat, .bodyweight, inc: 0),
        ex("split-squat-bw", "Bulgarian Split Squat (bodyweight)", .squat, .bodyweight, inc: 0),

        // Hinge
        ex("deadlift", "Conventional Deadlift", .hinge, .fullGym, inc: 10),
        ex("bb-rdl", "Barbell Romanian Deadlift", .hinge, .fullGym, inc: 10),
        ex("db-rdl", "Dumbbell Romanian Deadlift", .hinge, .dumbbells, inc: 5),
        ex("db-hip-thrust", "Dumbbell Hip Thrust", .hinge, .dumbbells, inc: 5),
        ex("sl-rdl-bw", "Single-Leg RDL (bodyweight)", .hinge, .bodyweight, inc: 0),
        ex("glute-bridge", "Single-Leg Glute Bridge", .hinge, .bodyweight, inc: 0),

        // Lunge
        ex("db-walking-lunge", "Dumbbell Walking Lunge", .lunge, .dumbbells, inc: 5),
        ex("db-step-up", "Dumbbell Step-Up", .lunge, .dumbbells, inc: 5),
        ex("reverse-lunge-bw", "Reverse Lunge", .lunge, .bodyweight, inc: 0),
        ex("step-up-bw", "Step-Up", .lunge, .bodyweight, inc: 0),

        // Horizontal push
        ex("bench-press", "Barbell Bench Press", .horizontalPush, .fullGym, inc: 5),
        ex("db-incline-press", "Incline Dumbbell Press", .horizontalPush, .dumbbells, inc: 5),
        ex("db-bench-press", "Dumbbell Bench Press", .horizontalPush, .dumbbells, inc: 5),
        ex("push-up", "Push-Up", .horizontalPush, .bodyweight, inc: 0),
        ex("decline-push-up", "Feet-Elevated Push-Up", .horizontalPush, .bodyweight, inc: 0),

        // Vertical push
        ex("ohp", "Barbell Overhead Press", .verticalPush, .fullGym, inc: 5),
        ex("db-shoulder-press", "Seated Dumbbell Shoulder Press", .verticalPush, .dumbbells, inc: 5),
        ex("pike-push-up", "Pike Push-Up", .verticalPush, .bodyweight, inc: 0),

        // Horizontal pull
        ex("bb-row", "Barbell Row", .horizontalPull, .fullGym, inc: 5),
        ex("cable-row", "Seated Cable Row", .horizontalPull, .fullGym, inc: 10),
        ex("db-row", "One-Arm Dumbbell Row", .horizontalPull, .dumbbells, inc: 5),
        ex("chest-supported-db-row", "Chest-Supported Dumbbell Row", .horizontalPull, .dumbbells, inc: 5),
        ex("inverted-row", "Inverted Row (table or bar)", .horizontalPull, .bodyweight, inc: 0),

        // Vertical pull
        ex("lat-pulldown", "Lat Pulldown", .verticalPull, .fullGym, inc: 10),
        ex("pull-up", "Pull-Up (assisted if needed)", .verticalPull, .fullGym, inc: 0),
        ex("db-pullover", "Dumbbell Pullover", .verticalPull, .dumbbells, compound: false, inc: 5),
        ex("towel-row", "Doorframe Towel Row", .verticalPull, .bodyweight, inc: 0),

        // Isolation
        ex("db-lateral-raise", "Dumbbell Lateral Raise", .shoulderIsolation, .dumbbells, compound: false, inc: 2.5),
        ex("face-pull", "Cable Face Pull", .shoulderIsolation, .fullGym, compound: false, inc: 5),
        ex("db-rear-delt-fly", "Dumbbell Rear Delt Fly", .shoulderIsolation, .dumbbells, compound: false, inc: 2.5),
        ex("ytw-raise", "Prone Y-T-W Raise", .shoulderIsolation, .bodyweight, compound: false, inc: 0),

        ex("db-curl", "Dumbbell Curl", .biceps, .dumbbells, compound: false, inc: 2.5),
        ex("cable-curl", "Cable Curl", .biceps, .fullGym, compound: false, inc: 5),
        ex("hammer-curl", "Hammer Curl", .biceps, .dumbbells, compound: false, inc: 2.5),
        ex("chin-up-negative", "Chin-Up Negatives", .biceps, .bodyweight, compound: false, inc: 0),

        ex("rope-pushdown", "Rope Triceps Pushdown", .triceps, .fullGym, compound: false, inc: 5),
        ex("db-overhead-ext", "Overhead Dumbbell Triceps Extension", .triceps, .dumbbells, compound: false, inc: 2.5),
        ex("bench-dip", "Bench Dip", .triceps, .bodyweight, compound: false, inc: 0),

        ex("calf-raise-machine", "Standing Calf Raise (machine)", .calves, .fullGym, compound: false, inc: 10),
        ex("db-calf-raise", "Dumbbell Calf Raise", .calves, .dumbbells, compound: false, inc: 5),
        ex("calf-raise-bw", "Single-Leg Calf Raise", .calves, .bodyweight, compound: false, inc: 0),

        ex("plank-shoulder-tap", "Plank Shoulder Tap", .core, .bodyweight, compound: false, inc: 0),
        ex("hanging-knee-raise", "Hanging Knee Raise", .core, .fullGym, compound: false, inc: 0),
        ex("dead-bug", "Dead Bug", .core, .bodyweight, compound: false, inc: 0),
    ]

    public static func exercise(id: String) -> Exercise? { all.first { $0.id == id } }

    /// Candidates for a pattern given what the user has, richest equipment first.
    public static func candidates(for pattern: MovementPattern, equipment: Equipment) -> [Exercise] {
        let available = equipment.available
        let tierOrder: [Equipment] = [.fullGym, .dumbbells, .bodyweight]
        return tierOrder
            .filter { available.contains($0) }
            .flatMap { tier in all.filter { $0.pattern == pattern && $0.equipment == tier } }
    }
}
