"use client";

import { currentStreak, estimatedOneRepMax, weekDays, weeklyAdherence } from "@/lib/core/rules";
import type { AppState } from "@/lib/store";
import { Stat } from "./ui";

export function ProgressTab({ state }: { state: AppState }) {
  const now = new Date();
  const verified = state.workouts.filter((w) => w.isVerified);

  const weeks = Array.from({ length: 8 }, (_, i) => {
    const d = new Date(now);
    d.setDate(d.getDate() - (7 - i) * 7);
    const monday = weekDays(d)[0];
    return { label: `${monday.getMonth() + 1}/${monday.getDate()}`, ...weeklyAdherence(state.enforcement, d) };
  });
  const maxScheduled = Math.max(1, ...weeks.map((w) => w.scheduled));

  const exercises = new Map<string, { name: string; best: number; sessions: number; last: string }>();
  for (const w of [...state.workouts].sort((a, b) => a.startedAt.localeCompare(b.startedAt))) {
    for (const log of w.exercises) {
      const done = log.sets.filter((s) => s.isDone);
      if (done.length === 0) continue;
      const best = Math.max(0, ...done.map((s) => estimatedOneRepMax(s) ?? 0));
      const top = done.reduce((a, b) => ((a.weight ?? 0) * a.reps >= (b.weight ?? 0) * b.reps ? a : b));
      const prev = exercises.get(log.planned.exercise.id);
      exercises.set(log.planned.exercise.id, {
        name: log.planned.exercise.name,
        best: Math.max(best, prev?.best ?? 0),
        sessions: (prev?.sessions ?? 0) + 1,
        last: top.weight ? `${top.weight} lb × ${top.reps}` : `${top.reps} reps`,
      });
    }
  }

  return (
    <main className="container stack" style={{ gap: 16 }}>
      <h1 className="title" style={{ paddingTop: 16 }}>Progress</h1>
      <div className="grid2">
        <Stat icon="✅" value={verified.length} label="Verified workouts" />
        <Stat icon="🔥" value={currentStreak(state.enforcement, now)} label="Streak" />
      </div>

      <div className="card">
        <strong>Weekly consistency</strong>
        <div className="bars" role="img" aria-label="Completed versus scheduled sessions, last 8 weeks">
          {weeks.map((w) => (
            <div className="bar" key={w.label}>
              <span className="small mono">{w.completed}/{w.scheduled}</span>
              <div className="track" style={{ maxHeight: `${(w.scheduled / maxScheduled) * 100}%` }}>
                <div className="fill" style={{ height: `${w.scheduled ? (w.completed / w.scheduled) * 100 : 0}%` }} />
              </div>
              <span className="small muted">{w.label}</span>
            </div>
          ))}
        </div>
      </div>

      {exercises.size > 0 && (
        <div className="card">
          <strong>Exercises</strong>
          <table className="list">
            <tbody>
              {[...exercises.entries()].sort((a, b) => b[1].sessions - a[1].sessions).map(([id, e]) => (
                <tr key={id}>
                  <td>
                    <strong>{e.name}</strong>
                    <div className="small muted">{e.sessions} sessions · last top set {e.last}</div>
                  </td>
                  <td className="mono" style={{ textAlign: "right", color: "var(--accent)" }}>
                    {e.best > 0 ? `e1RM ${Math.round(e.best)}` : ""}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div className="card">
        <strong>Recent sessions</strong>
        {state.workouts.length === 0 ? (
          <p className="muted small">Finish your first session and your progress shows up here.</p>
        ) : (
          <table className="list">
            <tbody>
              {[...state.workouts].sort((a, b) => b.startedAt.localeCompare(a.startedAt)).slice(0, 10).map((w) => (
                <tr key={w.id}>
                  <td>
                    <strong>{w.workoutName}</strong>
                    <div className="small muted">{new Date(w.startedAt).toLocaleString()}</div>
                  </td>
                  <td style={{ textAlign: "right" }}>{w.isVerified ? "✅" : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </main>
  );
}
