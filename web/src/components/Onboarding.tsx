"use client";

import { useState } from "react";
import { dayMinutes, generatePlan } from "@/lib/core/generator";
import {
  EQUIPMENT, EXPERIENCE, GOALS, recommendedSessionMinutes, WEEKDAY_SHORT,
  type Equipment, type Experience, type FitnessGoal, type TrainingProfile, type Weekday, type WorkoutMode,
} from "@/lib/core/types";
import { AI_ENABLED, personalize, type Personalization } from "@/lib/personalize";
import { completeOnboarding, type GymLocation } from "@/lib/store";
import { GymPicker } from "./GymPicker";
import { Option, SessionLengthPicker, WeekdayPicker } from "./ui";

const STEPS = ["welcome", "goal", "experience", "schedule", "setting", "gym", "plan"] as const;
type Step = (typeof STEPS)[number];

const GOAL_ICON: Record<FitnessGoal, string> = { buildMuscle: "💪", getStronger: "🏋️", generalFitness: "❤️", loseFat: "🔥" };

type AiState =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "done"; result: Personalization }
  | { status: "error"; message: string };

export function Onboarding() {
  const [step, setStep] = useState<Step>("welcome");
  const [goals, setGoals] = useState<FitnessGoal[]>(["buildMuscle"]);
  const [description, setDescription] = useState("");
  const [experience, setExperience] = useState<Experience>("beginner");
  const [days, setDays] = useState<Weekday[]>([2, 4, 6]);
  const [customMinutes, setCustomMinutes] = useState<number | null>(null);
  const [mode, setMode] = useState<WorkoutMode>("gym");
  const [equipment, setEquipment] = useState<Equipment>("fullGym");
  const [gym, setGym] = useState<GymLocation | null>(null);
  const [ai, setAi] = useState<AiState>({ status: "idle" });

  const selectedGoals: FitnessGoal[] = goals.length ? goals : ["buildMuscle"];
  const minutes = customMinutes ?? recommendedSessionMinutes(selectedGoals, experience);
  const base: TrainingProfile = {
    goals: selectedGoals, experience, equipment, mode, trainingDays: days, sessionMinutes: minutes,
    goalDescription: description.trim() || undefined,
  };
  const profile: TrainingProfile = ai.status === "done"
    ? {
        ...base,
        goals: [...new Set([...selectedGoals, ...ai.result.goals])],
        avoidExerciseIds: ai.result.avoidExerciseIds,
        focusPatterns: ai.result.focusPatterns,
        coachNote: ai.result.coachNote || undefined,
      }
    : base;
  const plan = generatePlan(profile); // cheap and deterministic — no memo needed

  const index = STEPS.indexOf(step);

  async function runPersonalization() {
    if (!AI_ENABLED || !description.trim()) return;
    setAi({ status: "loading" });
    try {
      setAi({ status: "done", result: await personalize(description, base) });
    } catch (e) {
      setAi({ status: "error", message: e instanceof Error ? e.message : "Something went wrong." });
    }
  }

  const go = (delta: number) => {
    let next = index + delta;
    if (STEPS[next] === "gym" && mode === "home") next += delta;
    if (next < 0 || next >= STEPS.length) return;
    if (STEPS[next] === "plan") void runPersonalization();
    setStep(STEPS[next]);
  };
  const toggleGoal = (g: FitnessGoal) => setGoals(goals.includes(g) ? goals.filter((x) => x !== g) : [...goals, g]);

  const canContinue =
    step === "goal" ? goals.length > 0 || description.trim().length > 0
    : step === "schedule" ? days.length > 0
    : step === "plan" ? ai.status !== "loading"
    : true;

  return (
    <main className="container">
      {step !== "welcome" && (
        <div className="row" style={{ marginBottom: 16 }}>
          <button className="btn-icon" aria-label="Back" onClick={() => go(-1)}>←</button>
          <div className="progress" style={{ flex: 1 }}>
            <div style={{ width: `${(index / (STEPS.length - 1)) * 100}%` }} />
          </div>
        </div>
      )}

      <div className="stack" style={{ gap: 16 }}>
        {step === "welcome" && (
          <div className="stack" style={{ gap: 18, paddingTop: 48 }}>
            <div style={{ fontSize: 52 }}>🏋️</div>
            <h1 className="title" style={{ fontSize: 40 }}>Want to scroll?<br />Earn it.</h1>
            <p className="muted" style={{ fontSize: 18 }}>
              GPS-GYM builds your training plan, holds you to it, and tracks your progress.
            </p>
            <div className="stack small" style={{ gap: 8 }}>
              <span>📋 A plan built for your goals</span>
              <span>🔒 Apps locked until you train (iPhone app)</span>
              <span>📍 Verified at your gym, privately</span>
            </div>
          </div>
        )}

        {step === "goal" && (
          <>
            <h1 className="title">What are your goals?</h1>
            <p className="muted">Select all that apply.</p>
            {GOALS.map((g) => (
              <Option key={g.id} title={g.title} icon={GOAL_ICON[g.id]} selected={goals.includes(g.id)} onClick={() => toggleGoal(g.id)} />
            ))}
            <label className="field" style={{ marginTop: 8 }}>
              <strong>Or describe it in your own words</strong>
              <textarea
                className="text"
                rows={3}
                maxLength={600}
                placeholder="e.g. Gain 5 lbs of muscle in 2 months. Bigger arms. My left knee hurts on squats."
                value={description}
                onChange={(e) => setDescription(e.target.value)}
              />
              <span className="small muted">
                {AI_ENABLED
                  ? "✨ We'll use this to personalize your plan."
                  : "We'll save this. AI personalization is coming soon — for now your plan uses the goals above."}
              </span>
            </label>
          </>
        )}

        {step === "experience" && (
          <>
            <h1 className="title">How experienced are you?</h1>
            {EXPERIENCE.map((e) => (
              <Option key={e.id} title={e.title} subtitle={e.subtitle} selected={experience === e.id} onClick={() => setExperience(e.id)} />
            ))}
          </>
        )}

        {step === "schedule" && (
          <>
            <h1 className="title">When will you train?</h1>
            <p className="muted">Apps lock on these days only. Keep at least one rest day.</p>
            <WeekdayPicker value={days} onChange={setDays} />
            {days.length > 4 && experience === "beginner" && (
              <p className="small" style={{ color: "var(--warn)" }}>
                Heads up: 3–4 days is plenty when you&apos;re starting out — and easier to stick with.
              </p>
            )}
            <SessionLengthPicker
              recommended={recommendedSessionMinutes(selectedGoals, experience)}
              custom={customMinutes}
              onChange={setCustomMinutes}
            />
          </>
        )}

        {step === "setting" && (
          <>
            <h1 className="title">Where do you train?</h1>
            <Option title="At a gym" subtitle="Location-verified check-in" icon="🏢" selected={mode === "gym"}
              onClick={() => { setMode("gym"); setEquipment("fullGym"); }} />
            <Option title="At home" subtitle="Verified by time and logged sets" icon="🏠" selected={mode === "home"}
              onClick={() => { setMode("home"); if (equipment === "fullGym") setEquipment("dumbbells"); }} />
            <strong style={{ marginTop: 8 }}>Equipment</strong>
            {EQUIPMENT.map((e) => (
              <Option key={e.id} title={e.title} selected={equipment === e.id} onClick={() => setEquipment(e.id)} />
            ))}
          </>
        )}

        {step === "gym" && (
          <>
            <h1 className="title">Set your gym</h1>
            <p className="muted">We only check location during workouts, and only store your distance from this spot.</p>
            <GymPicker value={gym} onChange={setGym} />
          </>
        )}

        {step === "plan" && (
          <>
            <h1 className="title">{ai.status === "loading" ? "Personalizing your plan…" : "Your plan is ready"}</h1>
            <p className="muted">{plan.name} · ~{minutes} min sessions</p>
            {ai.status === "done" && profile.coachNote && (
              <div className="card" style={{ borderColor: "var(--accent)" }}>
                <span className="eyebrow">✨ Personalized for you</span>
                <p>{profile.coachNote}</p>
              </div>
            )}
            {ai.status === "error" && (
              <p className="small" style={{ color: "var(--warn)" }}>
                Couldn&apos;t personalize with AI ({ai.message}). Here&apos;s your plan from your selections — you can retry later in Settings.
              </p>
            )}
            {plan.schedule.map((s) => {
              const day = plan.days.find((d) => d.id === s.workoutDayId)!;
              return (
                <div className="card" key={s.weekday} style={{ opacity: ai.status === "loading" ? 0.5 : 1 }}>
                  <div className="row">
                    <span className="eyebrow" style={{ width: 40 }}>{WEEKDAY_SHORT[s.weekday - 1]}</span>
                    <div>
                      <strong>{day.name}</strong>
                      <div className="small muted">{day.exercises.length} exercises · ~{dayMinutes(day)} min</div>
                    </div>
                  </div>
                </div>
              );
            })}
            <p className="small muted">
              On the web, GPS-GYM tracks your plan, workouts and streak. App locking needs the iPhone app.
            </p>
          </>
        )}
      </div>

      <div className="footer-bar">
        <button
          className="btn btn-primary"
          disabled={!canContinue}
          onClick={() => (step === "plan" ? completeOnboarding(profile, mode === "gym" ? gym : null) : go(1))}
        >
          {step === "plan" ? "Start training" : step === "gym" && !gym ? "Skip — set it later" : "Continue"}
        </button>
      </div>
    </main>
  );
}
