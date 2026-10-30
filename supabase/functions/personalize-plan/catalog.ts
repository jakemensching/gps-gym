// Exercise IDs the generator knows. Mirror of web/src/lib/core/exercises.ts and
// ios/Packages/GPSGymCore/Sources/GPSGymCore/ExerciseLibrary.swift — keep in sync.
// (Clients also drop unknown IDs, so drift fails safe.)

export const EXERCISES = [
  ["back-squat", "Barbell Back Squat", "squat"],
  ["leg-press", "Leg Press", "squat"],
  ["goblet-squat", "Goblet Squat", "squat"],
  ["db-front-squat", "Dumbbell Front Squat", "squat"],
  ["bw-squat", "Bodyweight Squat", "squat"],
  ["split-squat-bw", "Bulgarian Split Squat (bodyweight)", "squat"],
  ["deadlift", "Conventional Deadlift", "hinge"],
  ["bb-rdl", "Barbell Romanian Deadlift", "hinge"],
  ["db-rdl", "Dumbbell Romanian Deadlift", "hinge"],
  ["db-hip-thrust", "Dumbbell Hip Thrust", "hinge"],
  ["sl-rdl-bw", "Single-Leg RDL (bodyweight)", "hinge"],
  ["glute-bridge", "Single-Leg Glute Bridge", "hinge"],
  ["db-walking-lunge", "Dumbbell Walking Lunge", "lunge"],
  ["db-step-up", "Dumbbell Step-Up", "lunge"],
  ["reverse-lunge-bw", "Reverse Lunge", "lunge"],
  ["step-up-bw", "Step-Up", "lunge"],
  ["bench-press", "Barbell Bench Press", "horizontalPush"],
  ["db-incline-press", "Incline Dumbbell Press", "horizontalPush"],
  ["db-bench-press", "Dumbbell Bench Press", "horizontalPush"],
  ["push-up", "Push-Up", "horizontalPush"],
  ["decline-push-up", "Feet-Elevated Push-Up", "horizontalPush"],
  ["ohp", "Barbell Overhead Press", "verticalPush"],
  ["db-shoulder-press", "Seated Dumbbell Shoulder Press", "verticalPush"],
  ["pike-push-up", "Pike Push-Up", "verticalPush"],
  ["bb-row", "Barbell Row", "horizontalPull"],
  ["cable-row", "Seated Cable Row", "horizontalPull"],
  ["db-row", "One-Arm Dumbbell Row", "horizontalPull"],
  ["chest-supported-db-row", "Chest-Supported Dumbbell Row", "horizontalPull"],
  ["inverted-row", "Inverted Row", "horizontalPull"],
  ["lat-pulldown", "Lat Pulldown", "verticalPull"],
  ["pull-up", "Pull-Up", "verticalPull"],
  ["db-pullover", "Dumbbell Pullover", "verticalPull"],
  ["towel-row", "Doorframe Towel Row", "verticalPull"],
  ["db-lateral-raise", "Dumbbell Lateral Raise", "shoulderIsolation"],
  ["face-pull", "Cable Face Pull", "shoulderIsolation"],
  ["db-rear-delt-fly", "Dumbbell Rear Delt Fly", "shoulderIsolation"],
  ["ytw-raise", "Prone Y-T-W Raise", "shoulderIsolation"],
  ["db-curl", "Dumbbell Curl", "biceps"],
  ["cable-curl", "Cable Curl", "biceps"],
  ["hammer-curl", "Hammer Curl", "biceps"],
  ["chin-up-negative", "Chin-Up Negatives", "biceps"],
  ["rope-pushdown", "Rope Triceps Pushdown", "triceps"],
  ["db-overhead-ext", "Overhead Dumbbell Triceps Extension", "triceps"],
  ["bench-dip", "Bench Dip", "triceps"],
  ["calf-raise-machine", "Standing Calf Raise (machine)", "calves"],
  ["db-calf-raise", "Dumbbell Calf Raise", "calves"],
  ["calf-raise-bw", "Single-Leg Calf Raise", "calves"],
  ["plank-shoulder-tap", "Plank Shoulder Tap", "core"],
  ["hanging-knee-raise", "Hanging Knee Raise", "core"],
  ["dead-bug", "Dead Bug", "core"],
] as const;

export const EXERCISE_IDS = EXERCISES.map(([id]) => id) as unknown as [string, ...string[]];

export const PATTERNS = [
  "squat", "hinge", "lunge", "horizontalPush", "verticalPush", "horizontalPull", "verticalPull",
  "shoulderIsolation", "biceps", "triceps", "calves", "core",
] as const;

export const GOALS = ["buildMuscle", "getStronger", "generalFitness", "loseFat"] as const;
