"use client";

import { useState } from "react";
import { useAppState } from "@/lib/store";
import type { VerificationResult } from "@/lib/core/rules";
import type { WorkoutRecord } from "@/lib/store";
import { ActiveWorkout } from "./ActiveWorkout";
import { Onboarding } from "./Onboarding";
import { PlanTab } from "./PlanTab";
import { ProgressTab } from "./ProgressTab";
import { SettingsTab } from "./SettingsTab";
import { TodayTab } from "./TodayTab";
import { WorkoutResult } from "./WorkoutResult";

const TABS = [
  { id: "today", label: "Today", glyph: "🔥" },
  { id: "plan", label: "Plan", glyph: "📋" },
  { id: "progress", label: "Progress", glyph: "📈" },
  { id: "settings", label: "Settings", glyph: "⚙️" },
] as const;
type Tab = (typeof TABS)[number]["id"];

export function GymApp() {
  const state = useAppState();
  const [tab, setTab] = useState<Tab>("today");
  const [finished, setFinished] = useState<{ record: WorkoutRecord; result: VerificationResult } | null>(null);

  if (state === undefined) return <main className="container muted">Loading…</main>;
  if (state === null) return <Onboarding />;

  return (
    <>
      {tab === "today" && <TodayTab state={state} />}
      {tab === "plan" && <PlanTab state={state} />}
      {tab === "progress" && <ProgressTab state={state} />}
      {tab === "settings" && <SettingsTab state={state} />}

      <div className="tabbar">
        <nav>
          {TABS.map((t) => (
            <button key={t.id} aria-current={tab === t.id ? "page" : undefined} onClick={() => setTab(t.id)}>
              <span className="glyph" aria-hidden>{t.glyph}</span>
              {t.label}
            </button>
          ))}
        </nav>
      </div>

      {state.activeWorkout && <ActiveWorkout state={state} workout={state.activeWorkout} onFinished={setFinished} />}
      {finished && <WorkoutResult {...finished} onClose={() => setFinished(null)} />}
    </>
  );
}
