"use client";

import { useEffect, useState } from "react";
import { distanceMeters, LOCATION_LABEL, locationStatus, suggest, type VerificationResult } from "@/lib/core/rules";
import { isBodyweight, prescription } from "@/lib/core/types";
import {
  discardWorkout, finishWorkout, getState, history, policyFor, previewVerification, updateActiveWorkout, workoutTotals,
  type ActiveWorkout as Workout, type AppState, type SetEntry, type WorkoutRecord,
} from "@/lib/store";
import { currentPosition, formatDuration, Modal } from "./ui";

function useNow(intervalMs = 1000) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), intervalMs);
    return () => clearInterval(id);
  }, [intervalMs]);
  return now;
}

async function sampleLocation(state: AppState, workout: Workout) {
  if (workout.mode !== "gym" || !state.gym) return;
  const pos = await currentPosition();
  if (!pos) return;
  const sample = {
    date: new Date().toISOString(),
    distanceMeters: distanceMeters({ lat: pos.coords.latitude, lng: pos.coords.longitude }, state.gym),
    accuracyMeters: pos.coords.accuracy,
  };
  // Only distance + accuracy are stored — never coordinates.
  updateActiveWorkout((w) => (w.id === workout.id ? { ...w, locationSamples: [...w.locationSamples, sample] } : w));
}

export function ActiveWorkout({ state, workout, onFinished }: {
  state: AppState;
  workout: Workout;
  onFinished: (f: { record: WorkoutRecord; result: VerificationResult }) => void;
}) {
  const now = useNow();
  const [shortfall, setShortfall] = useState<VerificationResult | null>(null);
  const [confirmDiscard, setConfirmDiscard] = useState(false);
  const [finishing, setFinishing] = useState(false);

  // Check location at start and every 5 minutes while the page is open.
  useEffect(() => {
    void sampleLocation(state, workout);
    const id = setInterval(() => void sampleLocation(state, workout), 5 * 60_000);
    return () => clearInterval(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [workout.id]);

  const { planned, done } = workoutTotals(workout);
  const policy = policyFor(workout);
  const neededSets = Math.ceil(planned * policy.minimumSetCompletion);
  const loc = locationStatus(workout.locationSamples, workout.mode, policy);
  const restLeft = workout.restEndsAt ? new Date(workout.restEndsAt).getTime() - now : 0;

  function updateSet(exerciseIndex: number, entry: SetEntry) {
    updateActiveWorkout((w) => {
      const exercises = w.exercises.map((e, i) => {
        if (i !== exerciseIndex) return e;
        return { ...e, sets: e.sets.map((x) => (x.id === entry.id ? entry : x)) };
      });
      const prev = w.exercises[exerciseIndex].sets.find((x) => x.id === entry.id);
      const startedRest = entry.isDone && !prev?.isDone;
      const restEndsAt = startedRest
        ? new Date(Date.now() + w.exercises[exerciseIndex].planned.restSeconds * 1000).toISOString()
        : w.restEndsAt;
      return { ...w, exercises, restEndsAt };
    });
  }

  async function finish() {
    setFinishing(true);
    await sampleLocation(state, workout);
    setFinishing(false);
    // Re-read: the location sample above may have updated the workout.
    const result = previewVerification(getState()?.activeWorkout ?? workout);
    if (result.isVerified) {
      const saved = finishWorkout();
      if (saved) onFinished(saved);
    } else {
      setShortfall(result);
    }
  }

  return (
    <div className="overlay">
      <main className="container stack" style={{ gap: 16 }}>
        <div className="row" style={{ paddingTop: 8 }}>
          <button className="btn-icon" aria-label="Discard workout" onClick={() => setConfirmDiscard(true)}>✕</button>
          <strong style={{ flex: 1, textAlign: "center" }}>{workout.day.name}</strong>
          <span style={{ width: 36 }} />
        </div>

        <div className="card">
          <div className="row">
            <span className="mono" style={{ fontSize: 44, fontWeight: 800 }}>
              {formatDuration(now - new Date(workout.startedAt).getTime())}
            </span>
            <span className="spacer" />
            {workout.mode === "home" ? (
              <span className="pill">🏠 Home workout</span>
            ) : workout.locationSamples.length === 0 ? (
              <span className="pill">📍 Checking…</span>
            ) : (
              <span className={`pill ${loc === "atGym" ? "good" : "warn"}`}>📍 {LOCATION_LABEL[loc]}</span>
            )}
          </div>
          <div className="progress"><div style={{ width: `${(done / Math.max(1, planned)) * 100}%` }} /></div>
          <span className="small muted">
            {done}/{planned} sets · finish needs {policy.minimumMinutes}+ min and {neededSets}+ sets
          </span>
          {restLeft > 0 && (
            <div className="row pill good" style={{ justifyContent: "space-between", padding: "10px 12px", fontSize: 14 }}>
              <span>⏱ Rest {formatDuration(restLeft)}</span>
              <button className="btn-link" style={{ color: "var(--accent)", padding: 0 }}
                onClick={() => updateActiveWorkout((w) => ({ ...w, restEndsAt: null }))}>Skip</button>
            </div>
          )}
        </div>

        {workout.exercises.map((log, i) => {
          const bw = isBodyweight(log.planned.exercise);
          const tip = suggest(log.planned, history(state, log.planned.exercise.id));
          return (
            <div className="card" key={log.planned.exercise.id}>
              <div>
                <strong>{log.planned.exercise.name}</strong>
                <div className="small muted">{prescription(log.planned)} · rest {log.planned.restSeconds}s</div>
                <div className="small" style={{ color: "var(--accent)" }}>{tip.message}</div>
              </div>
              <div className={`set-row small muted ${bw ? "bw" : ""}`} style={{ fontWeight: 700 }}>
                <span>SET</span>{!bw && <span style={{ textAlign: "center" }}>LB</span>}<span style={{ textAlign: "center" }}>REPS</span><span />
              </div>
              {log.sets.map((set, n) => (
                <SetRow key={set.id} number={n + 1} set={set} bodyweight={bw} onChange={(entry) => updateSet(i, entry)} />
              ))}
            </div>
          );
        })}
      </main>

      <div className="footer-bar">
        <button className="btn btn-primary" disabled={finishing} onClick={finish}>
          {finishing ? "Verifying…" : "Finish workout"}
        </button>
      </div>

      {shortfall && (
        <Modal onClose={() => setShortfall(null)}>
          <h2 className="h2">Not quite yet</h2>
          {shortfall.unmetReasons.map((r) => <p key={r} className="muted">{r}</p>)}
          <button className="btn btn-primary" onClick={() => setShortfall(null)}>Keep training</button>
          <button className="btn btn-secondary" onClick={() => {
            const saved = finishWorkout();
            setShortfall(null);
            if (saved) onFinished(saved);
          }}>Save without verifying</button>
        </Modal>
      )}

      {confirmDiscard && (
        <Modal onClose={() => setConfirmDiscard(false)}>
          <h2 className="h2">Discard this workout?</h2>
          <p className="muted">Nothing will be saved.</p>
          <button className="btn btn-danger" onClick={discardWorkout}>Discard workout</button>
          <button className="btn-link" onClick={() => setConfirmDiscard(false)}>Cancel</button>
        </Modal>
      )}
    </div>
  );
}

/** Keeps raw text locally so partial input like "2." isn't reformatted mid-typing. */
function SetRow({ number, set, bodyweight, onChange }: {
  number: number; set: SetEntry; bodyweight: boolean; onChange: (s: SetEntry) => void;
}) {
  const [weight, setWeight] = useState(set.weight == null ? "" : String(set.weight));
  const [reps, setReps] = useState(String(set.reps));
  const parsed = (w: string, r: string, isDone: boolean): SetEntry => {
    const n = Number(w.replace(",", "."));
    return { ...set, weight: w.trim() === "" || Number.isNaN(n) ? null : n, reps: Number.parseInt(r, 10) || 0, isDone };
  };

  return (
    <div className={`set-row ${bodyweight ? "bw" : ""}`} style={{ opacity: set.isDone ? 0.75 : 1 }}>
      <strong>{number}</strong>
      {!bodyweight && (
        <input inputMode="decimal" aria-label={`Set ${number} weight`} value={weight}
          onChange={(e) => { setWeight(e.target.value); onChange(parsed(e.target.value, reps, set.isDone)); }} />
      )}
      <input inputMode="numeric" aria-label={`Set ${number} reps`} value={reps}
        onChange={(e) => { setReps(e.target.value); onChange(parsed(weight, e.target.value, set.isDone)); }} />
      <button className="set-check" aria-pressed={set.isDone} aria-label={`Complete set ${number}`}
        onClick={() => onChange(parsed(weight, reps, !set.isDone))}>
        {set.isDone ? "✓" : ""}
      </button>
    </div>
  );
}
