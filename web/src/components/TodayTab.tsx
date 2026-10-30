"use client";

import { useState } from "react";
import { dayMinutes, daySets } from "@/lib/core/generator";
import {
  canSwapRestDay, currentStreak, dayKey, dayStatus, weekDays, weeklyAdherence, type DayStatus,
} from "@/lib/core/rules";
import { WEEKDAY_SHORT, weekdayOf, workoutDayFor, type Weekday, type WorkoutDay } from "@/lib/core/types";
import { startWorkout, swapRestDayToday, type AppState } from "@/lib/store";
import { Modal, Stat } from "./ui";

const STATUS: Record<DayStatus, { icon: string; title: string; subtitle: string; tone: string }> = {
  locked: { icon: "🔒", title: "Training day — not done yet", subtitle: "Finish today's workout to earn your scroll.", tone: "var(--warn)" },
  unlockedByWorkout: { icon: "🔓", title: "Done — you earned it", subtitle: "Workout verified. Enjoy your scroll.", tone: "var(--accent)" },
  restDay: { icon: "😴", title: "Rest day", subtitle: "Recovery is part of the plan.", tone: "var(--muted)" },
  unlockedByRestSwap: { icon: "😴", title: "Rest day swap", subtitle: "Back at it next training day.", tone: "var(--muted)" },
  unlockedByEmergency: { icon: "⚠️", title: "Emergency unlock used", subtitle: "Back at it next training day.", tone: "var(--muted)" },
  notEnforced: { icon: "⏸️", title: "Not started yet", subtitle: "Your schedule starts on your next training day.", tone: "var(--muted)" },
};

function nextWorkout(state: AppState, from: Date): { weekday: Weekday; day: WorkoutDay } | null {
  const today = weekdayOf(from);
  for (let offset = 1; offset <= 7; offset++) {
    const weekday = (((today - 1 + offset) % 7) + 1) as Weekday;
    const day = workoutDayFor(state.plan, weekday);
    if (day) return { weekday, day };
  }
  return null;
}

export function TodayTab({ state }: { state: AppState }) {
  const [confirmRest, setConfirmRest] = useState(false);
  const now = new Date();
  const status = dayStatus(state.enforcement, now);
  const meta = STATUS[status];
  const today = workoutDayFor(state.plan, weekdayOf(now));
  const next = today ? null : nextWorkout(state, now);
  const week = weeklyAdherence(state.enforcement, now);

  return (
    <main className="container stack" style={{ gap: 16 }}>
      <h1 className="title" style={{ paddingTop: 16 }}>
        {now.toLocaleDateString(undefined, { weekday: "long", month: "short", day: "numeric" })}
      </h1>

      <div className="card status" style={{ borderColor: meta.tone }}>
        <div className="icon" style={{ background: "rgba(255,255,255,0.06)" }}>{meta.icon}</div>
        <div>
          <strong>{meta.title}</strong>
          <div className="small muted">{meta.subtitle}</div>
        </div>
      </div>

      {today ? (
        <WorkoutCard eyebrow="Today" day={today} cta={status === "unlockedByWorkout" ? "Train again" : "Start workout"} />
      ) : next ? (
        <div className="card">
          <span className="eyebrow">Rest day</span>
          <h2 className="h2">Recover. Eat. Sleep.</h2>
          <p className="muted">Next up: {next.day.name} on {WEEKDAY_SHORT[next.weekday - 1]}</p>
          <button className="btn btn-secondary" onClick={() => startWorkout(next.day)}>Train anyway</button>
        </div>
      ) : null}

      <div className="grid2">
        <Stat icon="🔥" value={currentStreak(state.enforcement, now)} label="Day streak" />
        <Stat icon="📅" value={`${week.completed}/${week.scheduled}`} label="This week" />
      </div>

      <div className="card week">
        {weekDays(now).map((d) => {
          const key = dayKey(d);
          const training = state.enforcement.trainingWeekdays.includes(weekdayOf(d));
          const done = state.enforcement.completedDays.includes(key);
          return (
            <div key={key}>
              <div className="small" style={{ color: key === dayKey(now) ? "var(--accent)" : "var(--muted)", fontWeight: 700 }}>
                {WEEKDAY_SHORT[weekdayOf(d) - 1][0]}
              </div>
              <div className={`dot ${training ? "training" : ""} ${done ? "done" : ""}`}>{done ? "✓" : ""}</div>
            </div>
          );
        })}
      </div>

      {status === "locked" && canSwapRestDay(state.enforcement, now) && (
        <button className="btn btn-secondary" onClick={() => setConfirmRest(true)}>Need a rest day?</button>
      )}

      {confirmRest && (
        <Modal onClose={() => setConfirmRest(false)}>
          <h2 className="h2">Take a rest day?</h2>
          <p className="muted">Feeling sick, sore or traveling? One rest-day swap per week. Your streak stays intact.</p>
          <button className="btn btn-primary" onClick={() => { swapRestDayToday(); setConfirmRest(false); }}>Make today a rest day</button>
          <button className="btn-link" onClick={() => setConfirmRest(false)}>Cancel</button>
        </Modal>
      )}
    </main>
  );
}

function WorkoutCard({ eyebrow, day, cta }: { eyebrow: string; day: WorkoutDay; cta: string }) {
  return (
    <div className="card">
      <span className="eyebrow">{eyebrow}</span>
      <h2 className="h2">{day.name}</h2>
      <p className="muted">{day.focus}</p>
      <div className="row small muted" style={{ flexWrap: "wrap" }}>
        <span>⏱ ~{dayMinutes(day)} min</span>
        <span>🏋️ {day.exercises.length} exercises</span>
        <span>🧱 {daySets(day)} sets</span>
      </div>
      <button className="btn btn-primary" onClick={() => startWorkout(day)}>{cta}</button>
    </div>
  );
}
