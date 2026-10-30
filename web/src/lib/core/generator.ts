import { candidates } from "./exercises";
import {
  isBodyweight, sortWeekdays,
  type Experience, type FitnessGoal, type MovementPattern, type PlannedExercise,
  type SlotRole, type TrainingPlan, type TrainingProfile, type WorkoutDay,
  GOAL_PRIORITY,
} from "./types";

// Mirrors WorkoutGenerator.swift. Deterministic: same profile → same plan.

interface Slot { pattern: MovementPattern; role: SlotRole; variant?: number }
interface DayTemplate { id: string; name: string; focus: string; slots: Slot[] }

const s = (pattern: MovementPattern, role: SlotRole, variant = 0): Slot => ({ pattern, role, variant });

const fullBodyA: DayTemplate = { id: "full-a", name: "Full Body A", focus: "Squat, press, row", slots: [
  s("squat", "primary"), s("horizontalPush", "primary"), s("horizontalPull", "secondary"),
  s("hinge", "secondary", 1), s("biceps", "accessory"), s("core", "accessory"),
] };
const fullBodyB: DayTemplate = { id: "full-b", name: "Full Body B", focus: "Hinge, overhead, pull", slots: [
  s("hinge", "primary"), s("verticalPush", "primary"), s("verticalPull", "secondary"),
  s("lunge", "secondary"), s("triceps", "accessory"), s("calves", "accessory"),
] };
const fullBodyC: DayTemplate = { id: "full-c", name: "Full Body C", focus: "Legs, incline, back", slots: [
  s("squat", "primary", 1), s("horizontalPush", "secondary", 1), s("horizontalPull", "secondary", 1),
  s("hinge", "secondary", 2), s("shoulderIsolation", "accessory"), s("core", "accessory", 1),
] };
const upperA: DayTemplate = { id: "upper-a", name: "Upper A", focus: "Horizontal push & pull", slots: [
  s("horizontalPush", "primary"), s("horizontalPull", "primary"), s("verticalPush", "secondary"),
  s("verticalPull", "secondary"), s("biceps", "accessory"), s("triceps", "accessory"),
] };
const upperB: DayTemplate = { id: "upper-b", name: "Upper B", focus: "Vertical push & pull", slots: [
  s("verticalPush", "primary"), s("verticalPull", "primary"), s("horizontalPush", "secondary", 1),
  s("horizontalPull", "secondary", 1), s("shoulderIsolation", "accessory"), s("biceps", "accessory", 1),
] };
const lowerA: DayTemplate = { id: "lower-a", name: "Lower A", focus: "Squat focus", slots: [
  s("squat", "primary"), s("hinge", "secondary", 1), s("lunge", "secondary"),
  s("calves", "accessory"), s("core", "accessory"),
] };
const lowerB: DayTemplate = { id: "lower-b", name: "Lower B", focus: "Hinge focus", slots: [
  s("hinge", "primary"), s("squat", "secondary", 1), s("lunge", "secondary", 1),
  s("calves", "accessory"), s("core", "accessory", 1),
] };
const push: DayTemplate = { id: "push", name: "Push", focus: "Chest, shoulders, triceps", slots: [
  s("horizontalPush", "primary"), s("verticalPush", "secondary"), s("horizontalPush", "secondary", 1),
  s("shoulderIsolation", "accessory"), s("triceps", "accessory"),
] };
const pull: DayTemplate = { id: "pull", name: "Pull", focus: "Back, rear delts, biceps", slots: [
  s("verticalPull", "primary"), s("horizontalPull", "secondary"), s("horizontalPull", "secondary", 1),
  s("shoulderIsolation", "accessory", 1), s("biceps", "accessory"),
] };
const legs: DayTemplate = { id: "legs", name: "Legs", focus: "Quads, hamstrings, glutes", slots: [
  s("squat", "primary"), s("hinge", "secondary", 1), s("lunge", "secondary"),
  s("calves", "accessory"), s("core", "accessory"),
] };

export function split(dayCount: number, experience: Experience): { name: string; rotation: DayTemplate[] } {
  if (experience === "beginner" || dayCount <= 3) {
    return { name: "Full Body", rotation: [fullBodyA, fullBodyB, fullBodyC].slice(0, Math.max(1, Math.min(dayCount, 3))) };
  }
  if (dayCount === 4) return { name: "Upper / Lower", rotation: [upperA, lowerA, upperB, lowerB] };
  if (dayCount === 5) return { name: "Upper / Lower + Push / Pull / Legs", rotation: [upperA, lowerA, push, pull, legs] };
  return { name: "Push / Pull / Legs", rotation: [push, pull, legs] };
}

interface Prescription { sets: number; repsLow: number; repsHigh: number; restSeconds: number }

const TABLE: Record<FitnessGoal, Record<SlotRole, [number, number, number, number]>> = {
  getStronger: { primary: [4, 3, 5, 180], secondary: [3, 6, 8, 120], accessory: [2, 8, 12, 75] },
  buildMuscle: { primary: [4, 6, 8, 150], secondary: [3, 8, 12, 90], accessory: [3, 10, 15, 60] },
  generalFitness: { primary: [3, 8, 10, 90], secondary: [3, 10, 12, 75], accessory: [2, 12, 15, 60] },
  loseFat: { primary: [3, 8, 12, 75], secondary: [3, 10, 15, 60], accessory: [2, 12, 15, 45] },
};

/**
 * With several goals, the most strength-leaning one drives the main lifts, the most
 * conditioning-leaning one drives accessories, and the middle one drives secondaries.
 */
export function goalForRole(goals: FitnessGoal[], role: SlotRole): FitnessGoal {
  const sorted = GOAL_PRIORITY.filter((g) => goals.includes(g));
  if (sorted.length === 0) return "buildMuscle";
  if (role === "primary") return sorted[0];
  if (role === "accessory") return sorted[sorted.length - 1];
  return sorted[Math.floor((sorted.length - 1) / 2)];
}

export function prescriptionFor(goals: FitnessGoal[], role: SlotRole, experience: Experience): Prescription {
  const [sets, repsLow, repsHigh, restSeconds] = TABLE[goalForRole(goals, role)][role];
  const p = { sets, repsLow, repsHigh, restSeconds };
  if (experience === "beginner" && role !== "accessory") p.sets = Math.max(2, p.sets - 1);
  if (experience === "advanced" && role === "primary") p.sets += 1;
  return p;
}

const WARMUP_MINUTES = 5;
const SECONDS_PER_SET = 45;

export function estimateMinutes(exercises: PlannedExercise[]): number {
  const seconds = exercises.reduce(
    (total, e) => total + e.sets * SECONDS_PER_SET + Math.max(0, e.sets - 1) * e.restSeconds + 60, 0,
  );
  return WARMUP_MINUTES + Math.ceil(seconds / 60);
}

export const dayMinutes = (day: WorkoutDay) => estimateMinutes(day.exercises);
export const daySets = (day: WorkoutDay) => day.exercises.reduce((n, e) => n + e.sets, 0);

function lastIndex<T>(items: T[], predicate: (item: T) => boolean): number {
  for (let i = items.length - 1; i >= 0; i--) if (predicate(items[i])) return i;
  return -1;
}

/** Drop accessories → trim secondary sets → drop secondaries (keep ≥ 3). */
export function fit(input: PlannedExercise[], budget: number): PlannedExercise[] {
  const exercises = input.map((e) => ({ ...e }));
  let i: number;
  while (estimateMinutes(exercises) > budget && (i = lastIndex(exercises, (e) => e.role === "accessory")) >= 0) {
    exercises.splice(i, 1);
  }
  while (estimateMinutes(exercises) > budget && (i = lastIndex(exercises, (e) => e.role === "secondary" && e.sets > 2)) >= 0) {
    exercises[i].sets -= 1;
  }
  while (estimateMinutes(exercises) > budget && exercises.length > 3 && (i = lastIndex(exercises, (e) => e.role === "secondary")) >= 0) {
    exercises.splice(i, 1);
  }
  return exercises;
}

function buildDay(template: DayTemplate, profile: TrainingProfile): WorkoutDay {
  const used = new Set<string>();
  const exercises: PlannedExercise[] = [];
  for (const slot of template.slots) {
    const avoid = profile.avoidExerciseIds ?? [];
    const options = candidates(slot.pattern, profile.equipment).filter((e) => !used.has(e.id) && !avoid.includes(e.id));
    if (options.length === 0) continue;
    const exercise = options[(slot.variant ?? 0) % options.length];
    used.add(exercise.id);
    const p = prescriptionFor(profile.goals, slot.role, profile.experience);
    if (profile.focusPatterns?.includes(slot.pattern)) p.sets += 1;
    if (isBodyweight(exercise)) {
      p.repsLow = Math.max(p.repsLow, 8);
      p.repsHigh = Math.max(p.repsHigh, 15);
    }
    exercises.push({ exercise, role: slot.role, ...p });
  }
  return { id: template.id, name: template.name, focus: template.focus, exercises: fit(exercises, profile.sessionMinutes) };
}

function progressionNotes(profile: TrainingProfile): string[] {
  const notes = [
    "Double progression: once you hit the top of the rep range on every set, add the smallest available weight next session.",
    "If you fall below the bottom of the rep range two sessions in a row, drop the weight ~10% and build back up.",
    "Leave 1–3 reps in the tank on most sets. Form first — stop a set when technique breaks down.",
    "Every 6–8 weeks, or when you feel run down, take a lighter week with half the sets.",
  ];
  if (profile.equipment === "bodyweight") {
    notes.push("Bodyweight moves: progress by adding reps, slowing the lowering phase to 3 seconds, or switching to the harder variation.");
  }
  if (profile.goals.includes("loseFat")) {
    notes.push("Lifting helps preserve muscle; fat loss is driven mostly by nutrition and daily activity.");
  }
  if (profile.coachNote) notes.unshift(profile.coachNote);
  notes.push("This is a general program, not medical advice. Results vary — stop and consult a professional if anything hurts.");
  return notes;
}

export function generatePlan(profile: TrainingProfile, now = new Date()): TrainingPlan {
  const weekdays = sortWeekdays(profile.trainingDays);
  const { name, rotation } = split(weekdays.length, profile.experience);
  const days = rotation.map((t) => buildDay(t, profile));
  return {
    name: `${weekdays.length}-Day ${name}`,
    days,
    schedule: weekdays.map((weekday, i) => ({ weekday, workoutDayId: days[i % days.length].id })),
    progressionNotes: progressionNotes(profile),
    createdAt: now.toISOString(),
  };
}
