"use client";

import type { ReactNode } from "react";
import { useState } from "react";
import {
  MAX_SESSION_MINUTES, MAX_TRAINING_DAYS, MIN_SESSION_MINUTES, MONDAY_FIRST, WEEKDAY_SHORT, type Weekday,
} from "@/lib/core/types";

export function Option({ title, subtitle, icon, selected, onClick }: {
  title: string; subtitle?: string; icon?: string; selected: boolean; onClick: () => void;
}) {
  return (
    <button type="button" className="option" aria-pressed={selected} onClick={onClick}>
      {icon && <span style={{ fontSize: 22, width: 28 }}>{icon}</span>}
      <span className="stack" style={{ gap: 2 }}>
        <strong>{title}</strong>
        {subtitle && <span className="small muted">{subtitle}</span>}
      </span>
      <span className="check" aria-hidden />
    </button>
  );
}

export function WeekdayPicker({ value, onChange }: { value: Weekday[]; onChange: (days: Weekday[]) => void }) {
  return (
    <div className="days" role="group" aria-label="Training days">
      {MONDAY_FIRST.map((d) => {
        const on = value.includes(d);
        return (
          <button
            key={d}
            type="button"
            className="day"
            aria-pressed={on}
            aria-label={WEEKDAY_SHORT[d - 1]}
            onClick={() => {
              if (on) onChange(value.filter((x) => x !== d));
              else if (value.length < MAX_TRAINING_DAYS) onChange([...value, d]);
            }}
          >
            {WEEKDAY_SHORT[d - 1][0]}
          </button>
        );
      })}
    </div>
  );
}

export function Segmented<T extends string | number>({ options, value, onChange, label }: {
  options: { value: T; label: string }[]; value: T; onChange: (v: T) => void; label: string;
}) {
  return (
    <div className="segmented" role="group" aria-label={label}>
      {options.map((o) => (
        <button key={String(o.value)} type="button" aria-pressed={o.value === value} onClick={() => onChange(o.value)}>
          {o.label}
        </button>
      ))}
    </div>
  );
}

/** Shows the recommended length; users can override it with their own number. */
export function SessionLengthPicker({ recommended, custom, onChange }: {
  recommended: number; custom: number | null; onChange: (minutes: number | null) => void;
}) {
  const [editing, setEditing] = useState(custom !== null);
  const [text, setText] = useState(String(custom ?? recommended));

  if (!editing) {
    return (
      <div className="card">
        <span className="small muted">Session length</span>
        <div className="row">
          <span style={{ fontSize: 28, fontWeight: 800 }}>⏱ {recommended} min</span>
          <span className="pill good">Recommended</span>
        </div>
        <span className="small muted">Based on your goals and experience.</span>
        <button type="button" className="btn-link" style={{ alignSelf: "flex-start", padding: 0, color: "var(--accent)" }}
          onClick={() => { setText(String(recommended)); setEditing(true); }}>
          Don&apos;t like the length? Enter your own
        </button>
      </div>
    );
  }

  const commit = (value: string) => {
    setText(value);
    const n = Number.parseInt(value, 10);
    if (Number.isFinite(n) && n >= MIN_SESSION_MINUTES && n <= MAX_SESSION_MINUTES) onChange(n);
  };
  const n = Number.parseInt(text, 10);
  const invalid = !Number.isFinite(n) || n < MIN_SESSION_MINUTES || n > MAX_SESSION_MINUTES;

  return (
    <div className="card">
      <label className="field">
        <span className="small muted">Your session length (minutes)</span>
        <input className="text" inputMode="numeric" aria-label="Session length in minutes" value={text}
          onChange={(e) => commit(e.target.value.replace(/[^0-9]/g, ""))} />
      </label>
      {invalid && <span className="small" style={{ color: "var(--warn)" }}>Pick {MIN_SESSION_MINUTES}–{MAX_SESSION_MINUTES} minutes.</span>}
      <button type="button" className="btn-link" style={{ alignSelf: "flex-start", padding: 0 }}
        onClick={() => { setEditing(false); onChange(null); }}>
        Use recommended ({recommended} min)
      </button>
    </div>
  );
}

export function Stat({ value, label, icon }: { value: ReactNode; label: string; icon?: string }) {
  return (
    <div className="stat">
      <div className="value">{icon && <span style={{ marginRight: 6 }}>{icon}</span>}{value}</div>
      <div className="small muted">{label}</div>
    </div>
  );
}

export function Modal({ children, onClose }: { children: ReactNode; onClose: () => void }) {
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" role="dialog" aria-modal onClick={(e) => e.stopPropagation()}>
        {children}
      </div>
    </div>
  );
}

export function formatDuration(ms: number): string {
  const total = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const mm = String(m).padStart(h > 0 ? 2 : 1, "0");
  return h > 0 ? `${h}:${mm}:${String(s).padStart(2, "0")}` : `${mm}:${String(s).padStart(2, "0")}`;
}

/** One-shot browser geolocation. Resolves null on denial/timeout. */
export function currentPosition(): Promise<GeolocationPosition | null> {
  return new Promise((resolve) => {
    if (typeof navigator === "undefined" || !navigator.geolocation) return resolve(null);
    navigator.geolocation.getCurrentPosition(resolve, () => resolve(null), {
      enableHighAccuracy: true, timeout: 15_000, maximumAge: 30_000,
    });
  });
}
