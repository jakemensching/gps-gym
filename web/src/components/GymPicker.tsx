"use client";

import { useState } from "react";
import type { GymLocation } from "@/lib/store";
import { currentPosition } from "./ui";

/** Web version: set the gym from your current location (no maps API key needed). */
export function GymPicker({ value, onChange }: { value: GymLocation | null; onChange: (g: GymLocation | null) => void }) {
  const [name, setName] = useState(value?.name ?? "");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function useHere() {
    setBusy(true);
    setMessage(null);
    const pos = await currentPosition();
    setBusy(false);
    if (!pos) {
      setMessage("Couldn't get your location. Allow location access in your browser, or choose “At home” instead.");
      return;
    }
    onChange({ name: name.trim() || "My gym", lat: pos.coords.latitude, lng: pos.coords.longitude });
    setMessage(`Saved (±${Math.round(pos.coords.accuracy)} m accuracy).`);
  }

  return (
    <div className="stack">
      <label className="field">
        <span className="small muted">Gym name</span>
        <input
          className="text"
          placeholder="e.g. ARC Champaign"
          value={name}
          onChange={(e) => {
            setName(e.target.value);
            if (value) onChange({ ...value, name: e.target.value || "My gym" });
          }}
        />
      </label>
      <button type="button" className="btn btn-secondary" onClick={useHere} disabled={busy}>
        {busy ? "Locating…" : value ? "📍 Update to my current location" : "📍 I'm at my gym right now"}
      </button>
      {value && (
        <a
          className="small"
          style={{ color: "var(--accent)" }}
          href={`https://www.openstreetmap.org/?mlat=${value.lat}&mlon=${value.lng}#map=17/${value.lat}/${value.lng}`}
          target="_blank"
          rel="noreferrer"
        >
          ✓ {value.name} — view on map
        </a>
      )}
      {message && <p className="small muted">{message}</p>}
      <p className="small muted">Not at the gym right now? Set it from the iPhone app (gym search), or update it here next visit.</p>
    </div>
  );
}
