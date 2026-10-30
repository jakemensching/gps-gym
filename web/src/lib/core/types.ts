// TypeScript mirror of ios/Packages/GPSGymCore. Keep the two in sync:
// same IDs, same numbers, same rules — tests on both sides pin the behavior.

export type FitnessGoal = "buildMuscle" | "getStronger" | "generalFitness" | "loseFat";
export type Experience = "beginner" | "intermediate" | "advanced";
export type Equipment = "fullGym" | "dumbbells" | "bodyweight";
export type WorkoutMode = "gym" | "home";
export type SlotRole = "primary" | "secondary" | "accessory";
export type MovementPattern =
  | "squat" | "hinge" | "lunge"
  | "horizontalPush" | "verticalPush" | "horizontalPull" | "verticalPull"
  | "shoulderIsolation" | "biceps" | "triceps" | "calves" | "core";

/** Matches Swift `Weekday` / Calendar: Sunday = 1 … Saturday = 7. */
export type Weekday = 1 | 2 | 3 | 4 | 5 | 6 | 7;

export const GOALS: { id: FitnessGoal; title: string }[] = [
  { id: "buildMuscle", title: "Build muscle" },
  { id: "getStronger", title: "Get stronger" },
  { id: "generalFitness", title: "General fitness" },
  { id: "loseFat", title: "Lose fat" },
];

export const EXPERIENCE: { id: Experience; title: string; subtitle: string }[] = [
  { id: "beginner", title: "Beginner", subtitle: "Under 6 months of consistent lifting" },
  { id: "intermediate", title: "Intermediate", subtitle: "6 months – 2 years" },
  { id: "advanced", title: "Advanced", subtitle: "2+ years, comfortable with barbell lifts" },
];

export const EQUIPMENT: { id: Equipment; title: string }[] = [
  { id: "fullGym", title: "Full gym" },
  { id: "dumbbells", title: "Dumbbells only" },
  { id: "bodyweight", title: "Bodyweight only" },
];

export const SESSION_LENGTHS = [30, 45, 60, 75, 90];
export const MAX_TRAINING_DAYS = 6;

export const WEEKDAY_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
export const MONDAY_FIRST: Weekday[] = [2, 3, 4, 5, 6, 7, 1];

export const mondayFirstIndex = (d: Weekday) => (d + 5) % 7;
export const sortWeekdays = (days: Weekday[]) =>
  [...days].sort((a, b) => mondayFirstIndex(a) - mondayFirstIndex(b));
export const weekdayOf = (date: Date): Weekday => (date.getDay() + 1) as Weekday;

export function availableEquipment(e: Equipment): Equipment[] {
  if (e === "fullGym") return ["fullGym", "dumbbells", "bodyweight"];
  if (e === "dumbbells") return ["dumbbells", "bodyweight"];
  return ["bodyweight"];
}

export interface TrainingProfile {
  /** One or more goals, any order. Never empty (generator falls back to buildMuscle). */
  goals: FitnessGoal[];
  experience: Experience;
  equipment: Equipment;
  mode: WorkoutMode;
  trainingDays: Weekday[];
  sessionMinutes: number;
  /** Exercises to leave out (injuries, dislikes) — set by the AI personalizer or the user. */
  avoidExerciseIds?: string[];
  /** Movement patterns to give an extra set (e.g. "biceps" for "bigger arms"). */
  focusPatterns?: MovementPattern[];
  /** The user's own words, kept so the plan can be re-personalized later. */
  goalDescription?: string;
  /** Short AI-written explanation of the plan, shown above the progression notes. */
  coachNote?: string;
}

/** Strength-leaning first; used to decide which goal drives which part of a session. */
export const GOAL_PRIORITY: FitnessGoal[] = ["getStronger", "buildMuscle", "generalFitness", "loseFat"];

export const MIN_SESSION_MINUTES = 20;
export const MAX_SESSION_MINUTES = 150;

/** Default session length so users don't have to guess. */
export function recommendedSessionMinutes(goals: FitnessGoal[], experience: Experience): number {
  const base = experience === "beginner" ? 45 : experience === "intermediate" ? 60 : 75;
  const conditioningOnly = goals.length > 0 && goals.every((g) => g === "generalFitness" || g === "loseFat");
  return conditioningOnly ? Math.max(30, base - 15) : base;
}

export interface Exercise {
  id: string;
  name: string;
  pattern: MovementPattern;
  equipment: Equipment;
  isCompound: boolean;
  /** Smallest load jump in lb; 0 = bodyweight (progress with reps). */
  loadIncrementLb: number;
}

export const isBodyweight = (e: Exercise) => e.loadIncrementLb === 0;

export interface PlannedExercise {
  exercise: Exercise;
  role: SlotRole;
  sets: number;
  repsLow: number;
  repsHigh: number;
  restSeconds: number;
}

export const prescription = (p: PlannedExercise) =>
  p.repsLow === p.repsHigh ? `${p.sets} × ${p.repsLow}` : `${p.sets} × ${p.repsLow}–${p.repsHigh}`;

export interface WorkoutDay {
  id: string;
  name: string;
  focus: string;
  exercises: PlannedExercise[];
}

export interface ScheduledDay {
  weekday: Weekday;
  workoutDayId: string;
}

export interface TrainingPlan {
  name: string;
  days: WorkoutDay[];
  schedule: ScheduledDay[];
  progressionNotes: string[];
  createdAt: string;
}

export function workoutDayFor(plan: TrainingPlan, weekday: Weekday): WorkoutDay | undefined {
  const id = plan.schedule.find((s) => s.weekday === weekday)?.workoutDayId;
  return id ? plan.days.find((d) => d.id === id) : undefined;
}
