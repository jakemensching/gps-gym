import { describe, expect, it } from "vitest";
import { exerciseById } from "./exercises";
import { dayMinutes, generatePlan } from "./generator";
import {
  canSwapRestDay, currentStreak, dayKey, dayStatus, emptyEnforcement, estimatedOneRepMax, evaluate,
  locationStatus, standardPolicy, suggest, weeklyAdherence, type EnforcementState, type LocationSample,
} from "./rules";
import {
  availableEquipment, EQUIPMENT, GOALS, SESSION_LENGTHS,
  type PlannedExercise, type TrainingProfile, type Weekday,
} from "./types";

// Same cases as ios/Packages/GPSGymCore/Tests — the two implementations must agree.

const profile = (o: Partial<TrainingProfile> = {}): TrainingProfile => ({
  goal: "buildMuscle", experience: "intermediate", equipment: "fullGym", mode: "gym",
  trainingDays: [2, 3, 5, 6], sessionMinutes: 60, ...o,
});

/** 2026-10-26 is a Monday (local time). */
const date = (day: number, month = 10) => new Date(2026, month - 1, day, 12);

describe("generator", () => {
  it("gives a 4-day intermediate an upper/lower split", () => {
    const plan = generatePlan(profile());
    expect(plan.days.map((d) => d.id)).toEqual(["upper-a", "lower-a", "upper-b", "lower-b"]);
    expect(plan.schedule.map((s) => s.weekday)).toEqual([2, 3, 5, 6]);
  });

  it("gives beginners full body", () => {
    const plan = generatePlan(profile({ experience: "beginner" }));
    expect(plan.schedule.map((s) => s.workoutDayId)).toEqual(["full-a", "full-b", "full-c", "full-a"]);
  });

  it("gives 6 days push/pull/legs", () => {
    const plan = generatePlan(profile({ trainingDays: [2, 3, 4, 5, 6, 7] }));
    expect(plan.days.map((d) => d.id)).toEqual(["push", "pull", "legs"]);
  });

  it("only uses available equipment, no duplicates, ≥ 3 exercises", () => {
    for (const { id: equipment } of EQUIPMENT) {
      for (const { id: goal } of GOALS) {
        for (const day of generatePlan(profile({ goal, equipment })).days) {
          expect(day.exercises.length).toBeGreaterThanOrEqual(3);
          expect(day.exercises.every((e) => availableEquipment(equipment).includes(e.exercise.equipment))).toBe(true);
          expect(new Set(day.exercises.map((e) => e.exercise.id)).size).toBe(day.exercises.length);
        }
      }
    }
  });

  it("fits the time budget when it can", () => {
    for (const minutes of SESSION_LENGTHS) {
      for (const { id: goal } of GOALS) {
        for (const day of generatePlan(profile({ goal, experience: "advanced", sessionMinutes: minutes })).days) {
          if (day.exercises.length > 3) expect(dayMinutes(day)).toBeLessThanOrEqual(minutes);
        }
      }
    }
  });

  it("matches the Swift generator for a reference profile", () => {
    // Pinned snapshot so the TS and Swift ports can be compared by eye.
    const plan = generatePlan(profile({ goal: "getStronger", experience: "advanced", equipment: "dumbbells" }));
    expect(plan.name).toBe("4-Day Upper / Lower");
    expect(plan.days[0].exercises.map((e) => e.exercise.id)[0]).toBe("db-incline-press");
  });
});

describe("progression", () => {
  const bench: PlannedExercise = {
    exercise: exerciseById("bench-press")!, role: "primary", sets: 3, repsLow: 6, repsHigh: 8, restSeconds: 120,
  };
  it("handles no history", () => expect(suggest(bench, []).kind).toBe("firstTime"));
  it("increases at top of range", () => {
    const s = suggest(bench, [[{ weight: 135, reps: 8 }, { weight: 135, reps: 8 }, { weight: 135, reps: 8 }]]);
    expect(s).toMatchObject({ kind: "increase", weight: 140 });
  });
  it("repeats in range", () => {
    expect(suggest(bench, [[{ weight: 135, reps: 8 }, { weight: 135, reps: 7 }, { weight: 135, reps: 6 }]]).kind).toBe("repeatWeight");
  });
  it("deloads after two misses", () => {
    const missed = [{ weight: 135, reps: 5 }, { weight: 135, reps: 4 }];
    expect(suggest(bench, [missed, missed])).toMatchObject({ kind: "deload", weight: 120 });
  });
  it("estimates 1RM", () => {
    expect(estimatedOneRepMax({ weight: 100, reps: 1 })).toBe(100);
    expect(estimatedOneRepMax({ weight: 150, reps: 10 })).toBeCloseTo(200);
    expect(estimatedOneRepMax({ weight: null, reps: 10 })).toBeNull();
  });
});

describe("verification", () => {
  const policy = standardPolicy(60);
  const sample = (distanceMeters: number, accuracyMeters = 20): LocationSample => ({ date: "", distanceMeters, accuracyMeters });
  const evidence = (minutes: number, completedSets: number, samples: LocationSample[], mode: "gym" | "home" = "gym") => ({
    startedAt: date(26), endedAt: new Date(date(26).getTime() + minutes * 60_000),
    plannedSets: 20, completedSets, mode, locationSamples: samples,
  });

  it("has a 20-minute floor", () => {
    expect(standardPolicy(30).minimumMinutes).toBe(20);
    expect(policy.minimumMinutes).toBe(36);
  });
  it("verifies at gym", () => {
    expect(evaluate(evidence(45, 15, [sample(30), sample(80)]), policy)).toMatchObject({ isVerified: true, location: "atGym", trust: "high" });
  });
  it("fails short sessions with two reasons", () => {
    const r = evaluate(evidence(10, 3, [sample(30)]), policy);
    expect(r.isVerified).toBe(false);
    expect(r.unmetReasons).toHaveLength(2);
  });
  it("fails away from gym", () => expect(evaluate(evidence(45, 15, [sample(2000)]), policy).location).toBe("awayFromGym"));
  it("gives accuracy the benefit of the doubt", () => expect(locationStatus([sample(250, 120)], "gym", policy)).toBe("atGym"));
  it("passes no-signal with low trust", () => {
    expect(evaluate(evidence(45, 15, [sample(5000, 1500)]), policy)).toMatchObject({ isVerified: true, location: "noSignal", trust: "low" });
  });
  it("skips location at home", () => {
    expect(evaluate(evidence(40, 12, [], "home"), policy)).toMatchObject({ isVerified: true, location: "notRequired" });
  });
});

describe("enforcement", () => {
  const state = (start = 26): EnforcementState => ({
    ...emptyEnforcement(), trainingWeekdays: [2, 4, 6] as Weekday[], enforcementStartDay: dayKey(date(start)),
  });

  it("formats day keys", () => expect(dayKey(date(30))).toBe("2026-10-30"));
  it("locks training days until completed", () => {
    const s = state();
    expect(dayStatus(s, date(26))).toBe("locked");
    expect(dayStatus(s, date(27))).toBe("restDay");
    s.completedDays.push("2026-10-26");
    expect(dayStatus(s, date(26))).toBe("unlockedByWorkout");
  });
  it("respects start day and pause", () => {
    const s = state(28);
    expect(dayStatus(s, date(26))).toBe("notEnforced");
    expect(dayStatus(s, date(28))).toBe("locked");
    s.isPaused = true;
    expect(dayStatus(s, date(28))).toBe("notEnforced");
  });
  it("allows one rest swap per week", () => {
    const s = state();
    expect(canSwapRestDay(s, date(26))).toBe(true);
    expect(canSwapRestDay(s, date(27))).toBe(false);
    s.restDaySwaps.push("2026-10-26");
    expect(dayStatus(s, date(26))).toBe("unlockedByRestSwap");
    expect(canSwapRestDay(s, date(28))).toBe(false);
    expect(canSwapRestDay(s, date(2, 11))).toBe(true);
  });
  it("computes streaks", () => {
    const s = state(19);
    s.completedDays = ["2026-10-19", "2026-10-21", "2026-10-23", "2026-10-26", "2026-10-28"];
    expect(currentStreak(s, date(30))).toBe(5);
    expect(currentStreak(s, date(2, 11))).toBe(0);
    s.restDaySwaps = ["2026-10-30"];
    expect(currentStreak(s, date(2, 11))).toBe(5);
    s.restDaySwaps = [];
    s.emergencyUnlocks = ["2026-10-30"];
    expect(currentStreak(s, date(2, 11))).toBe(0);
  });
  it("computes weekly adherence", () => {
    const s = state();
    s.completedDays = ["2026-10-26", "2026-10-28"];
    expect(weeklyAdherence(s, date(30))).toEqual({ completed: 2, scheduled: 3 });
  });
});
