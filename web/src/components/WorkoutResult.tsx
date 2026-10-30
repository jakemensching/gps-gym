"use client";

import { LOCATION_LABEL, type VerificationResult } from "@/lib/core/rules";
import type { WorkoutRecord } from "@/lib/store";
import { Modal, Stat } from "./ui";

export function WorkoutResult({ record, result, onClose }: { record: WorkoutRecord; result: VerificationResult; onClose: () => void }) {
  const minutes = Math.round((new Date(record.endedAt).getTime() - new Date(record.startedAt).getTime()) / 60_000);
  const done = record.exercises.flatMap((e) => e.sets.filter((s) => s.isDone));
  const volume = done.reduce((v, s) => v + (s.weight ?? 0) * s.reps, 0);

  return (
    <Modal onClose={onClose}>
      <div style={{ fontSize: 52, textAlign: "center" }}>{result.isVerified ? "🔓" : "✅"}</div>
      <h2 className="h2" style={{ textAlign: "center" }}>
        {result.isVerified ? "Verified. You earned it." : "Workout saved"}
      </h2>
      <div className="grid2" style={{ gridTemplateColumns: "1fr 1fr 1fr" }}>
        <Stat value={minutes} label="Minutes" />
        <Stat value={done.length} label="Sets" />
        <Stat value={volume > 0 ? Math.round(volume) : "—"} label="Volume (lb)" />
      </div>
      <span className="pill" style={{ alignSelf: "center" }}>📍 {LOCATION_LABEL[result.location]}</span>
      <button className="btn btn-primary" onClick={onClose}>Done</button>
    </Modal>
  );
}
