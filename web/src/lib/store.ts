"use client";

import { useSyncExternalStore } from "react";
import { dayMinutes, generatePlan } from "./core/generator";
import {
  dayKey, emptyEnforcement, evaluate, standardPolicy, suggest,
  type EnforcementState, type LocationSample, type LocationStatus, type LoggedSet, type TrustLevel, type VerificationResult,
} from "./core/rules";
import type { PlannedExercise, TrainingPlan, TrainingProfile, WorkoutDay, WorkoutMode } from "./core/types";

// Local-first store in localStorage, mirroring the iOS app's data model.
// Supabase sync (so web + iPhone share data) is a Week 2 task — see docs/ARCHITECTURE.md.

export interface GymLocation { name: string; lat: number; lng: number }
export interface SetEntry { id: string; weight: number | null; reps: number; isDone: boolean }
export interface ExerciseLog { planned: PlannedExercise; sets: SetEntry[] }

export interface ActiveWorkout {
  id: string;
  day: WorkoutDay;
  mode: WorkoutMode;
  startedAt: string;
  dayKey: string;
  exercises: ExerciseLog[];
  locationSamples: LocationSample[];
  restEndsAt: string | null;
}

export interface WorkoutRecord {
  id: string;
  workoutDayId: string;
  workoutName: string;
  dayKey: string;
  startedAt: string;
  endedAt: string;
  mode: WorkoutMode;
  plannedSets: number;
  exercises: ExerciseLog[];
  isVerified: boolean;
  locationStatus: LocationStatus;
  trust: TrustLevel;
}

export interface AppState {
  version: 1;
  profile: TrainingProfile;
  plan: TrainingPlan;
  gym: GymLocation | null;
  enforcement: EnforcementState;
  workouts: WorkoutRecord[];
  activeWorkout: ActiveWorkout | null;
}

const KEY = "gpsgym.v1";
const listeners = new Set<() => void>();
let cache: { raw: string | null; state: AppState | null } = { raw: null, state: null };

/** Upgrade data saved by older versions of the web app. */
function migrate(state: AppState): AppState {
  const legacy = state.profile as TrainingProfile & { goal?: TrainingProfile["goals"][number] };
  if (!Array.isArray(legacy.goals)) {
    state.profile = { ...legacy, goals: [legacy.goal ?? "buildMuscle"] };
  }
  return state;
}

function read(): AppState | null {
  let raw: string | null = null;
  try {
    raw = window.localStorage.getItem(KEY);
  } catch {
    return cache.state;
  }
  if (raw !== cache.raw) {
    try {
      cache = { raw, state: raw ? migrate(JSON.parse(raw)) : null };
    } catch {
      cache = { raw, state: null };
    }
  }
  return cache.state;
}

function write(state: AppState | null) {
  const raw = state ? JSON.stringify(state) : null;
  try {
    if (raw) window.localStorage.setItem(KEY, raw);
    else window.localStorage.removeItem(KEY);
  } catch {
    // Storage unavailable (private mode): keep working in memory for this session.
  }
  cache = { raw, state };
  listeners.forEach((l) => l());
}

function subscribe(listener: () => void) {
  listeners.add(listener);
  const onStorage = (e: StorageEvent) => e.key === KEY && listener();
  window.addEventListener("storage", onStorage);
  return () => {
    listeners.delete(listener);
    window.removeEventListener("storage", onStorage);
  };
}

/** `undefined` while rendering on the server / before hydration, `null` = not onboarded. */
export function useAppState(): AppState | null | undefined {
  return useSyncExternalStore(subscribe, read, () => undefined);
}

/** Current state outside React (e.g. right after an async step). */
export const getState = (): AppState | null => read();

function update(change: (s: AppState) => AppState) {
  const current = read();
  if (current) write(change(current));
}

const uid = () => (typeof crypto !== "undefined" && "randomUUID" in crypto ? crypto.randomUUID() : String(Math.random()).slice(2));

// MARK: Actions

export function completeOnboarding(profile: TrainingProfile, gym: GymLocation | null) {
  const plan = generatePlan(profile);
  write({
    version: 1, profile, plan, gym,
    enforcement: {
      ...emptyEnforcement(),
      trainingWeekdays: plan.schedule.map((s) => s.weekday),
      enforcementStartDay: dayKey(new Date()),
    },
    workouts: [],
    activeWorkout: null,
  });
}

export function updateProfile(profile: TrainingProfile) {
  update((s) => {
    const plan = generatePlan(profile);
    return { ...s, profile, plan, enforcement: { ...s.enforcement, trainingWeekdays: plan.schedule.map((d) => d.weekday) } };
  });
}

export const updateGym = (gym: GymLocation | null) => update((s) => ({ ...s, gym }));

export function swapRestDayToday() {
  update((s) => ({ ...s, enforcement: { ...s.enforcement, restDaySwaps: [...s.enforcement.restDaySwaps, dayKey(new Date())] } }));
}

export function history(state: AppState, exerciseId: string, limit = 5): LoggedSet[][] {
  return [...state.workouts]
    .sort((a, b) => b.startedAt.localeCompare(a.startedAt))
    .map((w) => w.exercises.find((e) => e.planned.exercise.id === exerciseId)?.sets.filter((x) => x.isDone)
      .map((x) => ({ weight: x.weight, reps: x.reps })) ?? [])
    .filter((sets) => sets.length > 0)
    .slice(0, limit);
}

export function startWorkout(day: WorkoutDay) {
  update((s) => ({
    ...s,
    activeWorkout: {
      id: uid(),
      day,
      mode: s.gym ? s.profile.mode : "home",
      startedAt: new Date().toISOString(),
      dayKey: dayKey(new Date()),
      exercises: day.exercises.map((planned) => {
        const suggestion = suggest(planned, history(s, planned.exercise.id));
        return {
          planned,
          sets: Array.from({ length: planned.sets }, () => ({ id: uid(), weight: suggestion.weight, reps: planned.repsHigh, isDone: false })),
        };
      }),
      locationSamples: [],
      restEndsAt: null,
    },
  }));
}

export function updateActiveWorkout(change: (w: ActiveWorkout) => ActiveWorkout) {
  update((s) => (s.activeWorkout ? { ...s, activeWorkout: change(s.activeWorkout) } : s));
}

export const discardWorkout = () => update((s) => ({ ...s, activeWorkout: null }));

export const workoutTotals = (w: { exercises: ExerciseLog[] }) => ({
  planned: w.exercises.reduce((n, e) => n + e.planned.sets, 0),
  done: w.exercises.reduce((n, e) => n + e.sets.filter((x) => x.isDone).length, 0),
});

export const policyFor = (w: ActiveWorkout) => standardPolicy(dayMinutes(w.day));

export function previewVerification(w: ActiveWorkout, end = new Date()): VerificationResult {
  const { planned, done } = workoutTotals(w);
  return evaluate(
    { startedAt: new Date(w.startedAt), endedAt: end, plannedSets: planned, completedSets: done, mode: w.mode, locationSamples: w.locationSamples },
    policyFor(w),
  );
}

export function finishWorkout(end = new Date()): { record: WorkoutRecord; result: VerificationResult } | null {
  const s = read();
  const w = s?.activeWorkout;
  if (!s || !w) return null;
  const result = previewVerification(w, end);
  const record: WorkoutRecord = {
    id: w.id, workoutDayId: w.day.id, workoutName: w.day.name, dayKey: w.dayKey,
    startedAt: w.startedAt, endedAt: end.toISOString(), mode: w.mode,
    plannedSets: workoutTotals(w).planned, exercises: w.exercises,
    isVerified: result.isVerified, locationStatus: result.location, trust: result.trust,
  };
  const completedDays = result.isVerified && !s.enforcement.completedDays.includes(w.dayKey)
    ? [...s.enforcement.completedDays, w.dayKey]
    : s.enforcement.completedDays;
  write({ ...s, workouts: [...s.workouts, record], activeWorkout: null, enforcement: { ...s.enforcement, completedDays } });
  return { record, result };
}

export const resetEverything = () => write(null);

export function exportData(): string {
  return JSON.stringify(read(), null, 2);
}
