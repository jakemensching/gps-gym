# 14–21 Day Roadmap

Day 0 = 2026-10-30. Tracks marked **∥** can run in parallel. Status lives in [`/CHECKLIST.md`](../CHECKLIST.md).

## Week 1 — Foundation + prove blocking (Days 1–7)
| Day | Jake (product/ops) | Engineering |
|---|---|---|
| 1 | **Apple Developer Program** active · register bundle IDs `com.jakemensching.gpsgym`, `.monitor`, `.shield` + App Group `group.com.jakemensching.gpsgym` · **submit Family Controls Distribution requests for all 3** | ✅ Done today: architecture, core logic + tests, iOS app, extensions, web app, CI |
| 1–2 | ∥ Start recruiting testers (screen 3 questions) | **POC on a real iPhone** — run [`POC-BLOCKING.md`](POC-BLOCKING.md) tests 1–4. Fix anything that breaks. |
| 2–3 | ∥ Write the App Store / TestFlight privacy text | Polish onboarding on device; app icon; launch screen |
| 3–5 | ∥ Line up an install session venue | Supabase project: auth (Sign in with Apple + email for web), `events` table, sync for setup + workouts (both clients) |
| 5–7 | ∥ Line up 10–20 testers | Hardening: authorization-revoked detection UX, timezone/day-boundary checks, crash-safe workout resume |

**Gate end of Week 1:** blocking loop proven on a physical iPhone (lock → workout → unlock → re-lock next day). If it fails, everything else stops until it works.

## Week 2 — Accountability system complete (Days 8–14)
| Track | Work |
|---|---|
| iOS | Real-gym testing (ARC/CRCE): GPS accuracy indoors, radius tuning; notification on training-day morning (if time) |
| Web | Deploy to Vercel; landing page waitlist form → Supabase |
| Data | Instrument metrics from `PRODUCT.md` (events: onboarding_completed, screen_time_authorized, apps_selected, workout_started/finished, verification_result, emergency_unlock, rest_swap, authorization_revoked) |
| Ops | **Day ~12 entitlement check:** approved → TestFlight. Not approved → schedule campus install session (dev-signed builds on registered devices). |

## Week 3 — Beta (Days 15–21)
- Onboard 10–20 testers (install session or TestFlight) + web-only control group
- Daily: crash/bug triage, verification false-fail review
- Day 14 of each tester: paywall/pre-order test + exit/check-in interview
- End of week: metrics review against decision rules in `PRODUCT.md`

## Critical path
`Developer account → entitlement request (Day 1)` → `POC on device (Day 2)` → `real-gym GPS test (Week 2)` → `distribution (TestFlight or install session)`

Everything else is parallel and can slip without blocking the beta.
