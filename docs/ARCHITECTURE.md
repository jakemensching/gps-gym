# Architecture

## Stack decision
| Layer | Choice | Why |
|---|---|---|
| iPhone app | **SwiftUI**, iOS 17+, Swift 5 mode | Screen Time APIs are native-only and need app extensions. React Native would still need native Swift for the extensions *and* a bridge — strictly more work. |
| Project file | **XcodeGen** (`ios/project.yml`) | Readable, reviewable, no `.xcodeproj` merge conflicts. |
| Shared logic | `GPSGymCore` Swift package (Foundation-only) | Used by the app **and** the extensions; unit-tested in CI. |
| iPhone persistence | JSON files (Application Support, file protection) + App Group `UserDefaults` for extension-shared state | Tiny data, Codable, zero migration surprises. |
| Web app | **Next.js 16** (App Router), TypeScript, plain CSS | Team already knows Next/Vercel. Fully client-side for now. |
| Web persistence | `localStorage` | No backend needed to work on it from a laptop. |
| Backend (Week 2) | **Supabase** (Auth, Postgres + RLS, Edge Functions) | Familiar, cheap, gives web↔iPhone sync and the metrics `events` table. |
| AI (post-MVP) | Claude via Supabase Edge Function | Keeps the API key server-side. Not needed for the beta. |
| Hosting | Vercel (web), TestFlight / dev installs (iOS) | |
| CI | GitHub Actions: Swift tests + unsigned iOS Simulator build (macOS), web lint/test/build | Verifies the iOS app compiles even when nobody has Xcode open. |

## Repository layout
```
ios/
  project.yml                       XcodeGen spec (3 targets)
  Packages/GPSGymCore/              Pure logic + XCTest
    TrainingModels.swift            Profile, plan, exercise types
    ExerciseLibrary.swift           Curated exercises by pattern/equipment
    WorkoutGenerator.swift          Split → slots → prescription → time fit
    Progression.swift               Double progression, e1RM
    Verification.swift              Duration + sets + location → verified?
    Enforcement.swift               Lock decision, streaks, adherence
  Shared/SharedStore.swift          App Group store + ShieldController (app + monitor ext)
  GPSGym/                           The app (App, Models, Services, Features, Components)
  DeviceActivityMonitorExtension/   Re-locks at the start of each day
  ShieldConfigurationExtension/     Custom shield screen
web/
  src/lib/core/                     TypeScript mirror of GPSGymCore (+ vitest)
  src/lib/store.ts                  localStorage store + actions
  src/components/                   Onboarding, Today, ActiveWorkout, Plan, Progress, Settings
  src/app/                          / (landing), /app (the app)
supabase/migrations/                Schema for Week 2 sync + metrics
docs/                               Feasibility, product, roadmap, POC script
```

## The enforcement loop
```
Onboarding ──► EnforcementState{trainingWeekdays, startDay} ──► App Group
                                       │
00:00 daily ── DeviceActivity ext ─────┤ intervalDidStart → ShieldController.sync()
App foreground ────────────────────────┤ refresh() → ShieldController.sync()
Verified workout ── completedDays += today ──► sync() → shield cleared
23:59 ── intervalDidEnd → clear (never carry a lock into tomorrow)
```
`EnforcementState.status(on:)` is the single source of truth — a pure function, tested, used identically by app and extension.

## Verification rules
- **Duration** ≥ max(20 min, 60% of the planned session estimate). Timer derives from `startedAt`, so backgrounding/force-quit doesn't matter.
- **Sets** ≥ 60% of planned sets logged.
- **Location (gym mode)**: one-shot fixes at start, every 5 min while open, and at finish. A sample is "inside" if `distance − accuracy ≤ 150 m`. ≥ 50% inside → at gym. No usable fix → **pass with low trust** (indoor GPS is unreliable; we don't punish honest users).
- **Home mode**: no location, medium trust.
- **Stored**: distance-to-gym + accuracy only. Never coordinates or tracks.

## Keeping Swift and TypeScript in sync
The generator/rules exist twice. Rules: same IDs, same numbers, mirrored tests (`GPSGymCoreTests.swift` ↔ `core.test.ts`). Change one → change both in the same PR. If drift becomes painful, move generation server-side (Edge Function) and have both clients fetch the plan.

## Privacy & security
- Screen Time tokens are opaque — we can't see which apps users lock.
- When-In-Use location only, during workouts only.
- Gym coordinates stay on-device (iPhone files / browser storage).
- No API keys in clients; Supabase anon key + RLS only.
