"use client";

import { useState } from "react";
import { EQUIPMENT, EXPERIENCE, GOALS, SESSION_LENGTHS, type TrainingProfile } from "@/lib/core/types";
import { exportData, resetEverything, updateGym, updateProfile, type AppState, type GymLocation } from "@/lib/store";
import { GymPicker } from "./GymPicker";
import { Modal, Segmented, WeekdayPicker } from "./ui";

export function SettingsTab({ state }: { state: AppState }) {
  const [profile, setProfile] = useState<TrainingProfile>(state.profile);
  const [gym, setGym] = useState<GymLocation | null>(state.gym);
  const [confirmReset, setConfirmReset] = useState(false);
  const dirty = JSON.stringify(profile) !== JSON.stringify(state.profile);
  const set = <K extends keyof TrainingProfile>(key: K, value: TrainingProfile[K]) => setProfile({ ...profile, [key]: value });

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
        <label className="field">
          <span className="small muted">Goal</span>
          <select className="text" value={profile.goal} onChange={(e) => set("goal", e.target.value as TrainingProfile["goal"])}>
            {GOALS.map((g) => <option key={g.id} value={g.id}>{g.title}</option>)}
          </select>
        </label>
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
        <span className="small muted">Session length</span>
        <Segmented label="Session length" value={profile.sessionMinutes} onChange={(v) => set("sessionMinutes", v)}
          options={SESSION_LENGTHS.map((m) => ({ value: m, label: `${m}` }))} />
        <span className="small muted">Training days</span>
        <WeekdayPicker value={profile.trainingDays} onChange={(v) => set("trainingDays", v)} />
        <button className="btn btn-primary" disabled={!dirty || profile.trainingDays.length === 0} onClick={() => updateProfile(profile)}>
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
