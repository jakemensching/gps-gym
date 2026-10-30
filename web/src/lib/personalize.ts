import { EXERCISES } from "./core/exercises";
import { GOALS, type FitnessGoal, type MovementPattern, type TrainingProfile } from "./core/types";

// The Claude API key lives ONLY in the server function (supabase/functions/personalize-plan).
// The browser just calls that function. Both values are public and baked in at build time.
const AI_URL = process.env.NEXT_PUBLIC_PLAN_AI_URL ?? "";
const AI_PUBLIC_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";

export const AI_ENABLED = AI_URL.length > 0;

export interface Personalization {
  goals: FitnessGoal[];
  avoidExerciseIds: string[];
  focusPatterns: MovementPattern[];
  coachNote: string;
}

const PATTERNS: MovementPattern[] = [
  "squat", "hinge", "lunge", "horizontalPush", "verticalPush", "horizontalPull", "verticalPull",
  "shoulderIsolation", "biceps", "triceps", "calves", "core",
];

/** Never trust the network: keep only values the generator knows about. */
export function sanitize(raw: unknown): Personalization {
  const r = (raw ?? {}) as Partial<Record<keyof Personalization, unknown>>;
  const list = (v: unknown) => (Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : []);
  const goalIds = GOALS.map((g) => g.id);
  const exerciseIds = new Set(EXERCISES.map((e) => e.id));
  return {
    goals: list(r.goals).filter((g): g is FitnessGoal => goalIds.includes(g as FitnessGoal)),
    avoidExerciseIds: list(r.avoidExerciseIds).filter((id) => exerciseIds.has(id)),
    focusPatterns: list(r.focusPatterns).filter((p): p is MovementPattern => PATTERNS.includes(p as MovementPattern)),
    coachNote: typeof r.coachNote === "string" ? r.coachNote.slice(0, 400) : "",
  };
}

export async function personalize(description: string, profile: TrainingProfile): Promise<Personalization> {
  if (!AI_ENABLED) throw new Error("AI personalization isn't connected yet.");
  const res = await fetch(AI_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(AI_PUBLIC_KEY && { Authorization: `Bearer ${AI_PUBLIC_KEY}`, apikey: AI_PUBLIC_KEY }),
    },
    body: JSON.stringify({
      description: description.slice(0, 600),
      profile: {
        goals: profile.goals, experience: profile.experience, equipment: profile.equipment,
        mode: profile.mode, trainingDays: profile.trainingDays.length, sessionMinutes: profile.sessionMinutes,
      },
    }),
  });
  if (!res.ok) throw new Error(`AI request failed (${res.status}).`);
  return sanitize(await res.json());
}
