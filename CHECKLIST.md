# GPS-GYM Dev Checklist

_Last updated: 2026-10-30 (Day 0). Keep this short and current._

## 🚧 Blockers / waiting on Jake
- [ ] **Apple Developer Program** membership active (needed for Family Controls + device installs)
- [ ] Register bundle IDs `com.jakemensching.gpsgym`, `.monitor`, `.shield` + App Group `group.com.jakemensching.gpsgym`
- [ ] **Submit Family Controls _Distribution_ entitlement requests for all 3 bundle IDs** (multi-week risk — see `docs/FEASIBILITY.md`)
- [ ] Set `DEVELOPMENT_TEAM` in `ios/project.yml`

- [ ] **To turn on AI goal personalization:** Supabase project + Anthropic API key → follow `docs/AI-PERSONALIZATION.md` (~10 min)

## 🔥 Current priority
- [ ] **Run the blocking POC on a physical iPhone** (`docs/POC-BLOCKING.md`, tests 1–8) and record results below

## ✅ Done
- [x] Repo set up (`jakemensching/gps-gym`), CI on GitHub Actions (Swift tests, iOS build, web lint/test/build)
- [x] Screen Time feasibility research + risk register (`docs/FEASIBILITY.md`)
- [x] Product/MVP definition, competitor scan, validation metrics, backlog (`docs/PRODUCT.md`)
- [x] Roadmap (`docs/ROADMAP.md`) and architecture (`docs/ARCHITECTURE.md`)
- [x] `GPSGymCore`: workout generator, progression, verification, enforcement/streaks — unit-tested (passes in CI)
- [x] iOS app: onboarding, Today, active workout (timer, rest timer, logging, location check), plan, progress (charts), settings
- [x] Screen Time: authorization, app picker, shield apply/clear, DeviceActivity monitor extension, custom shield extension, Blocking Lab
- [x] iOS app + both extensions compile (CI: `xcodebuild` Simulator build succeeds) — **not yet run on a device**
- [x] Web app: same flows minus blocking; 28 unit tests; end-to-end click-through verified in headless Chromium
- [x] Supabase schema drafted (`supabase/migrations/`) — not yet applied
- [x] Web live on GitHub Pages (`.github/workflows/pages.yml`)
- [x] Multi-select goals, recommended session length with custom override (web + iOS)
- [x] Web gym search by name + Google Maps preview + Google/Apple Maps links
- [x] AI goal personalization: `supabase/functions/personalize-plan` (Claude, key server-side) + web client with safe fallback — type-checked and mock-tested; **not yet deployed**

## ⏭️ Next up
- [ ] AI personalization in the iPhone app (same endpoint; text field already collected)
- [ ] Rate-limit / require sign-in for the AI endpoint before any public launch
- [ ] App icon + launch polish
- [ ] Supabase project: auth (Sign in with Apple / email), sync profile + workouts, `events` metrics
- [ ] Deploy web to Vercel; waitlist form on landing page
- [ ] Detect Screen Time revocation on foreground → warning + event
- [ ] Real-gym GPS test (ARC/CRCE) — tune radius / accuracy thresholds
- [ ] Recruit 10–20 testers; schedule install session

## 🧪 POC results
| Test | Device / iOS | Result | Notes |
|---|---|---|---|
| 1 Lock from app | | | |
| 2 Unlock from app | | | |
| 3 Real loop | | | |
| 4 Extension, app closed | | | |
| 5 Next-day re-lock | | | |
| 6 Reboot | | | |
| 7 Revoke | | | |
| 8 Safety valves | | | |
