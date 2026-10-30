"use client";

import { useState } from "react";
import { dayMinutes, generatePlan } from "@/lib/core/generator";
import {
  EQUIPMENT, EXPERIENCE, GOALS, SESSION_LENGTHS, WEEKDAY_SHORT,
  type Equipment, type Experience, type FitnessGoal, type TrainingProfile, type Weekday, type WorkoutMode,
} from "@/lib/core/types";
import { completeOnboarding, type GymLocation } from "@/lib/store";
import { GymPicker } from "./GymPicker";
import { Option, Segmented, WeekdayPicker } from "./ui";

const STEPS = ["welcome", "goal", "experience", "schedule", "setting", "gym", "plan"] as const;
type Step = (typeof STEPS)[number];

const GOAL_ICON: Record<FitnessGoal, string> = { buildMuscle: "💪", getStronger: "🏋️", generalFitness: "❤️", loseFat: "🔥" };

export function Onboarding() {
  const [step, setStep] = useState<Step>("welcome");
  const [goal, setGoal] = useState<FitnessGoal>("buildMuscle");
  const [experience, setExperience] = useState<Experience>("beginner");
  const [days, setDays] = useState<Weekday[]>([2, 4, 6]);
  const [minutes, setMinutes] = useState(60);
  const [mode, setMode] = useState<WorkoutMode>("gym");
  const [equipment, setEquipment] = useState<Equipment>("fullGym");
  const [gym, setGym] = useState<GymLocation | null>(null);

  const profile: TrainingProfile = { goal, experience, equipment, mode, trainingDays: days, sessionMinutes: minutes };
  const plan = generatePlan(profile); // cheap and deterministic — no memo needed

  const index = STEPS.indexOf(step);
  const go = (delta: number) => {
    let next = index + delta;
    if (STEPS[next] === "gym" && mode === "home") next += delta;
    if (next >= 0 && next < STEPS.length) setStep(STEPS[next]);
  };
  const canContinue = step === "schedule" ? days.length > 0 : true;

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
              <span>📋 A plan built for your goal</span>
              <span>🔒 Apps locked until you train (iPhone app)</span>
              <span>📍 Verified at your gym, privately</span>
            </div>
          </div>
        )}

        {step === "goal" && (
          <>
            <h1 className="title">What&apos;s your main goal?</h1>
            {GOALS.map((g) => (
              <Option key={g.id} title={g.title} icon={GOAL_ICON[g.id]} selected={goal === g.id} onClick={() => setGoal(g.id)} />
            ))}
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
            <strong>Session length</strong>
            <Segmented label="Session length" value={minutes} onChange={setMinutes}
              options={SESSION_LENGTHS.map((m) => ({ value: m, label: `${m} min` }))} />
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
            <h1 className="title">Your plan is ready</h1>
            <p className="muted">{plan.name}</p>
            {plan.schedule.map((s) => {
              const day = plan.days.find((d) => d.id === s.workoutDayId)!;
              return (
                <div className="card" key={s.weekday}>
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
