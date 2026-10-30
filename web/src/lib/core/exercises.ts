import { availableEquipment, type Equipment, type Exercise, type MovementPattern } from "./types";

const ex = (
  id: string, name: string, pattern: MovementPattern, equipment: Equipment, inc: number, compound = true,
): Exercise => ({ id, name, pattern, equipment, isCompound: compound, loadIncrementLb: inc });

/** Mirrors ExerciseLibrary.swift — order within a pattern matters. */
export const EXERCISES: Exercise[] = [
  ex("back-squat", "Barbell Back Squat", "squat", "fullGym", 10),
  ex("leg-press", "Leg Press", "squat", "fullGym", 10),
  ex("goblet-squat", "Goblet Squat", "squat", "dumbbells", 5),
  ex("db-front-squat", "Dumbbell Front Squat", "squat", "dumbbells", 5),
  ex("bw-squat", "Bodyweight Squat", "squat", "bodyweight", 0),
  ex("split-squat-bw", "Bulgarian Split Squat (bodyweight)", "squat", "bodyweight", 0),

  ex("deadlift", "Conventional Deadlift", "hinge", "fullGym", 10),
  ex("bb-rdl", "Barbell Romanian Deadlift", "hinge", "fullGym", 10),
  ex("db-rdl", "Dumbbell Romanian Deadlift", "hinge", "dumbbells", 5),
  ex("db-hip-thrust", "Dumbbell Hip Thrust", "hinge", "dumbbells", 5),
  ex("sl-rdl-bw", "Single-Leg RDL (bodyweight)", "hinge", "bodyweight", 0),
  ex("glute-bridge", "Single-Leg Glute Bridge", "hinge", "bodyweight", 0),

  ex("db-walking-lunge", "Dumbbell Walking Lunge", "lunge", "dumbbells", 5),
  ex("db-step-up", "Dumbbell Step-Up", "lunge", "dumbbells", 5),
  ex("reverse-lunge-bw", "Reverse Lunge", "lunge", "bodyweight", 0),
  ex("step-up-bw", "Step-Up", "lunge", "bodyweight", 0),

  ex("bench-press", "Barbell Bench Press", "horizontalPush", "fullGym", 5),
  ex("db-incline-press", "Incline Dumbbell Press", "horizontalPush", "dumbbells", 5),
  ex("db-bench-press", "Dumbbell Bench Press", "horizontalPush", "dumbbells", 5),
  ex("push-up", "Push-Up", "horizontalPush", "bodyweight", 0),
  ex("decline-push-up", "Feet-Elevated Push-Up", "horizontalPush", "bodyweight", 0),

  ex("ohp", "Barbell Overhead Press", "verticalPush", "fullGym", 5),
  ex("db-shoulder-press", "Seated Dumbbell Shoulder Press", "verticalPush", "dumbbells", 5),
  ex("pike-push-up", "Pike Push-Up", "verticalPush", "bodyweight", 0),

  ex("bb-row", "Barbell Row", "horizontalPull", "fullGym", 5),
  ex("cable-row", "Seated Cable Row", "horizontalPull", "fullGym", 10),
  ex("db-row", "One-Arm Dumbbell Row", "horizontalPull", "dumbbells", 5),
  ex("chest-supported-db-row", "Chest-Supported Dumbbell Row", "horizontalPull", "dumbbells", 5),
  ex("inverted-row", "Inverted Row (table or bar)", "horizontalPull", "bodyweight", 0),

  ex("lat-pulldown", "Lat Pulldown", "verticalPull", "fullGym", 10),
  ex("pull-up", "Pull-Up (assisted if needed)", "verticalPull", "fullGym", 0),
  ex("db-pullover", "Dumbbell Pullover", "verticalPull", "dumbbells", 5, false),
  ex("towel-row", "Doorframe Towel Row", "verticalPull", "bodyweight", 0),

  ex("db-lateral-raise", "Dumbbell Lateral Raise", "shoulderIsolation", "dumbbells", 2.5, false),
  ex("face-pull", "Cable Face Pull", "shoulderIsolation", "fullGym", 5, false),
  ex("db-rear-delt-fly", "Dumbbell Rear Delt Fly", "shoulderIsolation", "dumbbells", 2.5, false),
  ex("ytw-raise", "Prone Y-T-W Raise", "shoulderIsolation", "bodyweight", 0, false),

  ex("db-curl", "Dumbbell Curl", "biceps", "dumbbells", 2.5, false),
  ex("cable-curl", "Cable Curl", "biceps", "fullGym", 5, false),
  ex("hammer-curl", "Hammer Curl", "biceps", "dumbbells", 2.5, false),
  ex("chin-up-negative", "Chin-Up Negatives", "biceps", "bodyweight", 0, false),

  ex("rope-pushdown", "Rope Triceps Pushdown", "triceps", "fullGym", 5, false),
  ex("db-overhead-ext", "Overhead Dumbbell Triceps Extension", "triceps", "dumbbells", 2.5, false),
  ex("bench-dip", "Bench Dip", "triceps", "bodyweight", 0, false),

  ex("calf-raise-machine", "Standing Calf Raise (machine)", "calves", "fullGym", 10, false),
  ex("db-calf-raise", "Dumbbell Calf Raise", "calves", "dumbbells", 5, false),
  ex("calf-raise-bw", "Single-Leg Calf Raise", "calves", "bodyweight", 0, false),

  ex("plank-shoulder-tap", "Plank Shoulder Tap", "core", "bodyweight", 0, false),
  ex("hanging-knee-raise", "Hanging Knee Raise", "core", "fullGym", 0, false),
  ex("dead-bug", "Dead Bug", "core", "bodyweight", 0, false),
];

export const exerciseById = (id: string) => EXERCISES.find((e) => e.id === id);

/** Candidates for a pattern, richest equipment tier first. */
export function candidates(pattern: MovementPattern, equipment: Equipment): Exercise[] {
  const tiers: Equipment[] = ["fullGym", "dumbbells", "bodyweight"];
  const available = availableEquipment(equipment);
  return tiers
    .filter((t) => available.includes(t))
    .flatMap((tier) => EXERCISES.filter((e) => e.pattern === pattern && e.equipment === tier));
}
