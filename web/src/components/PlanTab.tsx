"use client";

import { useState } from "react";
import { dayMinutes, daySets } from "@/lib/core/generator";
import { MONDAY_FIRST, prescription, WEEKDAY_SHORT, workoutDayFor } from "@/lib/core/types";
import type { AppState } from "@/lib/store";

export function PlanTab({ state }: { state: AppState }) {
  const [openDay, setOpenDay] = useState<string | null>(state.plan.days[0]?.id ?? null);
  const { plan } = state;

  return (
    <main className="container stack" style={{ gap: 16 }}>
      <h1 className="title" style={{ paddingTop: 16 }}>{plan.name}</h1>

      <div className="card">
        <strong>Weekly schedule</strong>
        <table className="list">
          <tbody>
            {MONDAY_FIRST.map((w) => {
              const day = workoutDayFor(plan, w);
              return (
                <tr key={w}>
                  <td className="muted" style={{ width: 56 }}>{WEEKDAY_SHORT[w - 1]}</td>
                  <td>{day ? <strong>{day.name}</strong> : <span className="muted">Rest</span>}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {plan.days.map((day) => (
        <div className="card" key={day.id}>
          <button className="row" style={{ background: "none", border: 0, padding: 0, cursor: "pointer", textAlign: "left" }}
            aria-expanded={openDay === day.id} onClick={() => setOpenDay(openDay === day.id ? null : day.id)}>
            <div style={{ flex: 1 }}>
              <strong>{day.name}</strong>
              <div className="small muted">{day.focus} · ~{dayMinutes(day)} min · {daySets(day)} sets</div>
            </div>
            <span className="muted">{openDay === day.id ? "▾" : "▸"}</span>
          </button>
          {openDay === day.id && (
            <table className="list">
              <tbody>
                {day.exercises.map((e) => (
                  <tr key={e.exercise.id}>
                    <td>
                      <strong>{e.exercise.name}</strong>
                      <div className="small muted">{e.role} · rest {e.restSeconds}s</div>
                    </td>
                    <td className="mono" style={{ textAlign: "right", color: "var(--accent)", fontWeight: 700 }}>{prescription(e)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      ))}

      <div className="card">
        <strong>How to progress</strong>
        {plan.progressionNotes.map((n) => <p key={n} className="small muted">• {n}</p>)}
      </div>
    </main>
  );
}
