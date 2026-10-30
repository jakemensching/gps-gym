"use client";

import { useState } from "react";
import { EQUIPMENT, EXPERIENCE, GOALS, recommendedSessionMinutes, type TrainingProfile } from "@/lib/core/types";
import { AI_ENABLED, personalize } from "@/lib/personalize";
import { exportData, resetEverything, updateGym, updateProfile, type AppState, type GymLocation } from "@/lib/store";
import { GymPicker } from "./GymPicker";
import { Modal, Segmented, SessionLengthPicker, WeekdayPicker } from "./ui";

export function SettingsTab({ state }: { state: AppState }) {
  const [profile, setProfile] = useState<TrainingProfile>(state.profile);
  const [gym, setGym] = useState<GymLocation | null>(state.gym);
  const [confirmReset, setConfirmReset] = useState(false);
  const [aiBusy, setAiBusy] = useState(false);
  const [aiMessage, setAiMessage] = useState<string | null>(null);
  const dirty = JSON.stringify(profile) !== JSON.stringify(state.profile);
  const set = <K extends keyof TrainingProfile>(key: K, value: TrainingProfile[K]) => setProfile({ ...profile, [key]: value });

  async function rePersonalize() {
    if (!profile.goalDescription?.trim()) return;
    setAiBusy(true);
    setAiMessage(null);
    try {
      const r = await personalize(profile.goalDescription, profile);
      setProfile({
        ...profile,
        goals: [...new Set([...profile.goals, ...r.goals])],
        avoidExerciseIds: r.avoidExerciseIds,
        focusPatterns: r.focusPatterns,
        coachNote: r.coachNote || undefined,
      });
      setAiMessage("Done — review and tap “Save & regenerate plan”.");
    } catch (e) {
      setAiMessage(e instanceof Error ? e.message : "AI personalization failed.");
    } finally {
      setAiBusy(false);
    }
  }

  function download() {
    const blob = new Blob([exportData()], { type: "application/json" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "gps-gym-data.json";
    a.click();
    URL.revokeObjectURL(a.href);
  }

  return (
    <main className="container stack" style={{ gap: 16 }}>
      <h1 className="title" style={{ paddingTop: 16 }}>Settings</h1>

      <div className="card">
        <strong>App blocking</strong>
        <p className="small muted">
          Browsers can&apos;t lock other apps. Blocking runs in the GPS-GYM iPhone app using Apple&apos;s Screen Time — your plan
          and workouts work the same here.
        </p>
      </div>

      <div className="card">
        <strong>Training</strong>
        <span className="small muted">Goals (select all that apply)</span>
        <div className="row" style={{ flexWrap: "wrap", gap: 8 }}>
          {GOALS.map((g) => {
            const on = profile.goals.includes(g.id);
            return (
              <button key={g.id} type="button" className={`pill ${on ? "good" : ""}`} aria-pressed={on}
                style={{ border: 0, cursor: "pointer", fontSize: 14, padding: "8px 12px" }}
                onClick={() => set("goals", on ? profile.goals.filter((x) => x !== g.id) : [...profile.goals, g.id])}>
                {on ? "✓ " : ""}{g.title}
              </button>
            );
          })}
        </div>
        <label className="field">
          <span className="small muted">Your goal in your own words</span>
          <textarea className="text" rows={2} maxLength={600} value={profile.goalDescription ?? ""}
            placeholder="e.g. Bigger arms, bad left knee"
            onChange={(e) => set("goalDescription", e.target.value || undefined)} />
        </label>
        {AI_ENABLED && (
          <button type="button" className="btn btn-secondary" disabled={aiBusy || !profile.goalDescription?.trim()} onClick={rePersonalize}>
            {aiBusy ? "Personalizing…" : "✨ Personalize with AI"}
          </button>
        )}
        {aiMessage && <span className="small muted">{aiMessage}</span>}
        <label className="field">
          <span className="small muted">Experience</span>
          <select className="text" value={profile.experience} onChange={(e) => set("experience", e.target.value as TrainingProfile["experience"])}>
            {EXPERIENCE.map((x) => <option key={x.id} value={x.id}>{x.title}</option>)}
          </select>
        </label>
        <label className="field">
          <span className="small muted">Equipment</span>
          <select className="text" value={profile.equipment} onChange={(e) => set("equipment", e.target.value as TrainingProfile["equipment"])}>
            {EQUIPMENT.map((x) => <option key={x.id} value={x.id}>{x.title}</option>)}
          </select>
        </label>
        <span className="small muted">Where</span>
        <Segmented label="Where" value={profile.mode} onChange={(v) => set("mode", v)}
          options={[{ value: "gym", label: "Gym" }, { value: "home", label: "Home" }]} />
        <SessionLengthPicker
          recommended={recommendedSessionMinutes(profile.goals, profile.experience)}
          custom={profile.sessionMinutes === recommendedSessionMinutes(profile.goals, profile.experience) ? null : profile.sessionMinutes}
          onChange={(m) => set("sessionMinutes", m ?? recommendedSessionMinutes(profile.goals, profile.experience))}
        />
        <span className="small muted">Training days</span>
        <WeekdayPicker value={profile.trainingDays} onChange={(v) => set("trainingDays", v)} />
        <button className="btn btn-primary" disabled={!dirty || profile.trainingDays.length === 0 || profile.goals.length === 0} onClick={() => updateProfile(profile)}>
          Save & regenerate plan
        </button>
        <span className="small muted">Your workout history is kept.</span>
      </div>

      <div className="card">
        <strong>Gym location</strong>
        <GymPicker value={gym} onChange={(g) => { setGym(g); updateGym(g); }} />
      </div>

      <div className="card">
        <strong>Your data</strong>
        <p className="small muted">Stored only in this browser. Gym coordinates never leave your device.</p>
        <button className="btn btn-secondary" onClick={download}>Export data (JSON)</button>
        <button className="btn btn-danger" onClick={() => setConfirmReset(true)}>Reset everything</button>
      </div>

      {confirmReset && (
        <Modal onClose={() => setConfirmReset(false)}>
          <h2 className="h2">Reset everything?</h2>
          <p className="muted">Removes your plan, workout history and settings from this browser.</p>
          <button className="btn btn-danger" onClick={resetEverything}>Erase all data</button>
          <button className="btn-link" onClick={() => setConfirmReset(false)}>Cancel</button>
        </Modal>
      )}
    </main>
  );
}
