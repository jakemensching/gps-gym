import { isBodyweight, weekdayOf, type PlannedExercise, type Weekday, type WorkoutMode } from "./types";

// Mirrors Progression.swift, Verification.swift and Enforcement.swift.

// MARK: Progression

export interface LoggedSet { weight: number | null; reps: number }

export type SuggestionKind = "firstTime" | "increase" | "repeatWeight" | "deload" | "addReps";
export interface Suggestion { kind: SuggestionKind; weight: number | null; message: string }

export const formatWeight = (w: number) => (Number.isInteger(w) ? String(w) : w.toFixed(1));

/** @param history completed sets per previous session, most recent first. */
export function suggest(planned: PlannedExercise, history: LoggedSet[][]): Suggestion {
  const last = history[0];
  if (!last || last.length === 0) {
    return {
      kind: "firstTime", weight: null,
      message: isBodyweight(planned.exercise)
        ? `Aim for ${planned.repsLow}–${planned.repsHigh} clean reps.`
        : `Pick a weight you can lift for ${planned.repsHigh} reps with 1–3 left in the tank.`,
    };
  }
  const weights = last.map((s) => s.weight).filter((w): w is number => w != null);
  const lastWeight = weights.length ? Math.max(...weights) : null;
  const hitTop = last.length >= planned.sets && last.every((s) => s.reps >= planned.repsHigh);
  const missed = (session: LoggedSet[]) => session.some((s) => s.reps < planned.repsLow);
  const missedTwice = history.length >= 2 && missed(history[0]) && missed(history[1]);

  if (isBodyweight(planned.exercise) || lastWeight == null) {
    return hitTop
      ? { kind: "addReps", weight: null, message: "You maxed the range — slow the lowering to 3s or use a harder variation." }
      : { kind: "repeatWeight", weight: null, message: "Beat last time by at least one rep." };
  }
  if (hitTop) {
    const next = lastWeight + planned.exercise.loadIncrementLb;
    return { kind: "increase", weight: next, message: `Top of the range on every set. Go ${formatWeight(next)} lb.` };
  }
  if (missedTwice) {
    const next = Math.round((lastWeight * 0.9) / 5) * 5;
    return { kind: "deload", weight: next, message: `Two tough sessions — reset to ${formatWeight(next)} lb and build back.` };
  }
  return { kind: "repeatWeight", weight: lastWeight, message: `Stay at ${formatWeight(lastWeight)} lb and add reps.` };
}

export function estimatedOneRepMax(set: LoggedSet): number | null {
  if (!set.weight || set.weight <= 0 || set.reps <= 0) return null;
  return set.reps === 1 ? set.weight : set.weight * (1 + set.reps / 30);
}

// MARK: Verification

export interface LocationSample { date: string; distanceMeters: number; accuracyMeters: number }

export interface VerificationPolicy {
  minimumMinutes: number;
  minimumSetCompletion: number;
  gymRadiusMeters: number;
  maxUsableAccuracyMeters: number;
}

export const standardPolicy = (plannedMinutes: number): VerificationPolicy => ({
  minimumMinutes: Math.max(20, Math.floor(plannedMinutes * 0.6)),
  minimumSetCompletion: 0.6,
  gymRadiusMeters: 150,
  maxUsableAccuracyMeters: 200,
});

export type LocationStatus = "atGym" | "awayFromGym" | "noSignal" | "notRequired";
export type TrustLevel = "high" | "medium" | "low";

export const LOCATION_LABEL: Record<LocationStatus, string> = {
  atGym: "At gym", awayFromGym: "Not at gym", noSignal: "No GPS signal", notRequired: "Home workout",
};

export interface SessionEvidence {
  startedAt: Date;
  endedAt: Date;
  plannedSets: number;
  completedSets: number;
  mode: WorkoutMode;
  locationSamples: LocationSample[];
}

export interface VerificationResult {
  isVerified: boolean;
  durationMet: boolean;
  setsMet: boolean;
  location: LocationStatus;
  trust: TrustLevel;
  unmetReasons: string[];
}

export function locationStatus(samples: LocationSample[], mode: WorkoutMode, policy: VerificationPolicy): LocationStatus {
  if (mode !== "gym") return "notRequired";
  const usable = samples.filter((s) => s.accuracyMeters >= 0 && s.accuracyMeters <= policy.maxUsableAccuracyMeters);
  if (usable.length === 0) return "noSignal";
  const inside = usable.filter((s) => s.distanceMeters - s.accuracyMeters <= policy.gymRadiusMeters);
  return inside.length / usable.length >= 0.5 ? "atGym" : "awayFromGym";
}

export function evaluate(e: SessionEvidence, policy: VerificationPolicy): VerificationResult {
  const minutes = (e.endedAt.getTime() - e.startedAt.getTime()) / 60_000;
  const durationMet = minutes >= policy.minimumMinutes;
  const required = Math.ceil(e.plannedSets * policy.minimumSetCompletion);
  const setsMet = e.completedSets >= Math.max(1, required);
  const location = locationStatus(e.locationSamples, e.mode, policy);

  const reasons: string[] = [];
  if (!durationMet) {
    reasons.push(`Train at least ${policy.minimumMinutes} min (${Math.ceil(policy.minimumMinutes - minutes)} to go).`);
  }
  if (!setsMet) reasons.push(`Log at least ${required} of ${e.plannedSets} sets (${e.completedSets} so far).`);
  if (location === "awayFromGym") {
    reasons.push("You don't appear to be at your gym. Switch to a home workout or check your gym location in Settings.");
  }
  const trust: TrustLevel = location === "atGym" ? "high" : location === "notRequired" ? "medium" : "low";
  return { isVerified: reasons.length === 0, durationMet, setsMet, location, trust, unmetReasons: reasons };
}

/** Haversine distance in meters. */
export function distanceMeters(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
  const R = 6_371_000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

// MARK: Enforcement / streaks

export const dayKey = (date: Date) =>
  `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;

export type DayStatus =
  | "restDay" | "notEnforced" | "locked" | "unlockedByWorkout" | "unlockedByRestSwap" | "unlockedByEmergency";

export interface EnforcementState {
  trainingWeekdays: Weekday[];
  enforcementStartDay: string | null;
  isPaused: boolean;
  completedDays: string[];
  restDaySwaps: string[];
  emergencyUnlocks: string[];
}

export const emptyEnforcement = (): EnforcementState => ({
  trainingWeekdays: [], enforcementStartDay: null, isPaused: false,
  completedDays: [], restDaySwaps: [], emergencyUnlocks: [],
});

export function dayStatus(state: EnforcementState, date: Date): DayStatus {
  const key = dayKey(date);
  if (!state.trainingWeekdays.includes(weekdayOf(date))) return "restDay";
  if (state.completedDays.includes(key)) return "unlockedByWorkout";
  if (state.restDaySwaps.includes(key)) return "unlockedByRestSwap";
  if (state.emergencyUnlocks.includes(key)) return "unlockedByEmergency";
  if (state.isPaused || !state.enforcementStartDay || key < state.enforcementStartDay) return "notEnforced";
  return "locked";
}

const addDays = (date: Date, n: number) => {
  const d = new Date(date);
  d.setDate(d.getDate() + n);
  return d;
};

export function weekDays(date: Date): Date[] {
  const start = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const monday = addDays(start, -((start.getDay() + 6) % 7));
  return Array.from({ length: 7 }, (_, i) => addDays(monday, i));
}

export function canSwapRestDay(state: EnforcementState, date: Date): boolean {
  if (!state.trainingWeekdays.includes(weekdayOf(date))) return false;
  const keys = weekDays(date).map(dayKey);
  return !state.restDaySwaps.some((k) => keys.includes(k));
}

export function currentStreak(state: EnforcementState, asOf: Date): number {
  let streak = 0;
  const today = dayKey(asOf);
  let day = new Date(asOf.getFullYear(), asOf.getMonth(), asOf.getDate());
  for (let i = 0; i < 400; i++) {
    const key = dayKey(day);
    if (state.trainingWeekdays.includes(weekdayOf(day))) {
      if (state.completedDays.includes(key)) streak++;
      else if (!(state.restDaySwaps.includes(key) || key === today)) break;
    }
    day = addDays(day, -1);
  }
  return streak;
}

export function weeklyAdherence(state: EnforcementState, date: Date): { completed: number; scheduled: number } {
  const days = weekDays(date);
  const scheduled = days.filter(
    (d) => state.trainingWeekdays.includes(weekdayOf(d)) && !state.restDaySwaps.includes(dayKey(d)),
  ).length;
  const completed = days.filter((d) => state.completedDays.includes(dayKey(d))).length;
  return { completed: Math.min(completed, scheduled), scheduled };
}
