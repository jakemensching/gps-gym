"use client";

import type { ReactNode } from "react";
import { MAX_TRAINING_DAYS, MONDAY_FIRST, WEEKDAY_SHORT, type Weekday } from "@/lib/core/types";

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
