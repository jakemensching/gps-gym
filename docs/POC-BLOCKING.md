# Proof of Concept: Lock & Unlock Apps

The single most important technical dependency. Run on a **physical iPhone (iOS 17+)** — Screen Time doesn't work in the Simulator.

## Setup (≈15 min)
1. Paid Apple Developer account signed into Xcode (Xcode → Settings → Accounts).
2. `brew install xcodegen`
3. In `ios/project.yml`, set `DEVELOPMENT_TEAM` to your Team ID. If `com.jakemensching.gpsgym` is taken, change the 3 bundle IDs and the App Group there **and** `AppGroup.identifier` in `ios/Shared/SharedStore.swift`.
4. `cd ios && xcodegen generate && open GPSGym.xcodeproj`
5. Select your iPhone, scheme **GPSGym**, Run. Xcode's automatic signing registers the App Group and Family Controls (Development) capability.
6. Onboard: pick training days that **include today**, toggle **"Start locking today"**, grant Screen Time, pick 1–2 apps (e.g. Instagram).
7. Settings → Developer → **Blocking Lab**.

## Tests
| # | Test | Steps | Pass if |
|---|---|---|---|
| 1 | Lock from app | Lab → "Apply shield now" → open Instagram | GPS-GYM "Earn your scroll" shield appears |
| 2 | Unlock from app | Lab → "Clear shield now" → open Instagram | Opens normally |
| 3 | Real loop | Lab → "Re-sync" (shield ON) → "Simulate verified workout" → open Instagram | Shield gone; Today says "Unlocked — you earned it" |
| 4 | Extension, app closed | Lab → "Schedule 15-min lock starting in 1 min" → **force-quit GPS-GYM** → wait 1–2 min → open Instagram → wait ~16 min | Shield appears with the app closed, then lifts (or matches today's real status) |
| 5 | Next-day re-lock | Leave a training day after it's completed; next scheduled training day, open Instagram before working out | Shielded without opening GPS-GYM |
| 6 | Reboot | Apply shield, reboot phone | Still shielded |
| 7 | Revoke | iOS Settings → Screen Time → revoke GPS-GYM | Shield lifts; GPS-GYM shows "Blocking is off" on next open |
| 8 | Safety valves | Emergency unlock / rest-day swap from Today | Unlocks immediately; streak behaves as documented |

Record results (device, iOS version, pass/fail, notes) in `CHECKLIST.md`. Test 4 and 5 are the ones forum reports flag as flaky — if they fail intermittently, the app still re-syncs on every foreground, but we need to know how often.
