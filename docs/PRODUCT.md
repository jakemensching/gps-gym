# Product: MVP, Competition, Validation

## One-liner
**Want to scroll? Earn it.** GPS-GYM builds your training plan, locks your distracting apps on training days, and unlocks them when a workout is verified.

## Two forms
| | iPhone app (SwiftUI) | Web app (Next.js) |
|---|---|---|
| Onboarding + plan generator | ✅ | ✅ |
| Workout logging, timer, rest timer | ✅ | ✅ |
| Gym check-in (location) | ✅ Core Location, gym search | ✅ Browser geolocation, "I'm here" pin |
| Progress, streaks, adherence | ✅ | ✅ |
| **App blocking** | ✅ Screen Time | ❌ Impossible in a browser |
| Data | On-device | In-browser |

The web app is for building/testing from a laptop and for testers without a registered iPhone. Data sync between the two is a Week 2 item (Supabase).

## MVP scope (what ships in the beta)
1. **Onboarding (~60s):** goal, experience, training days, session length, gym/home, equipment, gym location, apps to lock.
2. **Plan generator:** deterministic templates → split, exercises, sets × reps, rest, est. duration, progression rules.
3. **Blocking:** lock picked apps on scheduled days; unlock on verified workout; re-lock next training day automatically.
4. **Verification:** duration ≥ max(20, 60% of planned) min + ≥ 60% of sets logged + gym check-in (gym mode). No GPS signal = pass with low trust.
5. **Safety valves:** 1 rest-day swap/week (streak-neutral), unlimited emergency unlock (logged, breaks streak), pause, and iOS-level revoke.
6. **Progress:** verified workouts, streak, weekly adherence (8 weeks), per-exercise top sets + e1RM, double-progression weight suggestions.

### Decision: deterministic generator, not an LLM (for now)
| | Deterministic (chosen) | LLM API | Hybrid (later) |
|---|---|---|---|
| Cost | $0 | $ per plan | low |
| Latency/offline | instant, offline | seconds, online | — |
| Safety | can't hallucinate a bad program | needs guardrails + eval | templates bound the LLM |
| Testability | unit-tested | hard | medium |
| "Personalized" feel | good | great copy | great |

Personalization lives in the rules (split by frequency + experience, rep ranges by goal, equipment filtering, time-budget fitting). **Post-MVP hybrid:** keep templates as the source of truth, and let Claude (server-side via a Supabase Edge Function — never an API key in the client) explain the plan, swap exercises on request, or adjust after a missed week.

## Competitive landscape (as of Oct 2026)
The "lock apps until you go to the gym" niche is **crowded and commoditized.**

| App | Mechanism | Notes |
|---|---|---|
| **GYMTIME** (getgymtime.app) | Location check-in at gym unlocks apps; streaks & goals | "No Gym, No Scroll." Could not verify ratings/downloads/AI features — App Store pages aren't reachable from this research environment. Treat the brief's numbers (9 ratings, ~700 downloads) as unverified. |
| GymLock: Screen Time Focus | Auto-locks when you enter a set gym location | Uses background location |
| GymProof | Blocks social during a gym window until check-in | |
| LockedOut | Blocks until a goal (gym via GPS check-in) | Freemium subscription |
| GymsLock / SweatLock | Photo of gym equipment unlocks | Photo verification |
| ScrollToll, Push Up Time, Reptime, RepGate, UNLK, Focused Fitness | Camera-counted reps / exercise unlocks | "Do 20 push-ups to scroll" model |

### Is our differentiation real?
- ❌ "GPS + app blocking" alone: **not a differentiator.** At least 5 apps do it.
- ❌ "AI workout plans" alone: Fitbod, Hevy, etc. own this.
- ✅ **The closed loop is the wedge:** _goal → plan → today's prescribed workout is the unlock condition → logged sets prove it → progression adapts next session._ Competitors verify *presence* ("you were at the gym"); we verify *the plan was done* and make next week better. That's what turns a blocker into a coach.
- ⚠️ Risk: the loop only matters if people actually follow the plan. If testers ignore the plan and just want "check in = unlock," we're a me-too blocker and should pivot positioning (or merge into an existing logger via HealthKit).

**Implication:** validation must test whether *the plan* adds value over a plain blocker, not just whether blocking works.

## Validation plan (10–50 testers, 3 weeks)

### Ideal first customer
College student (UIUC first — campus rec centers like ARC/CRCE), 18–24, **wants** to lift 3–4×/week, **currently** manages ≤ 2, and self-reports 3+ hrs/day of TikTok/Instagram. Beginner–intermediate. Not the gym rat who already logs every set in Hevy.

### How to recruit
Dorm floors, club sports, intro lifting classes, r/UIUC, friends-of-friends. Screen with 3 questions (current frequency, target frequency, daily screen time). Install session on campus (also solves the entitlement problem).

### Metrics (instrument these — Week 2 Supabase `events` table)
| Question | Metric | Target signal |
|---|---|---|
| Will people restrict their own apps? | % of onboarded users who grant Screen Time + pick ≥ 1 app | ≥ 70% |
| …and keep it on? | % still authorized at day 7 / day 14 (revocation rate) | ≥ 60% at D14 |
| Does blocking improve consistency? | Sessions completed ÷ scheduled, week 1–3, vs. self-reported baseline; iPhone vs web-only (no-blocking) testers | +1 session/week vs baseline; blocking cohort > web cohort |
| Does personalization matter? | % of sessions that follow the generated workout (≥ 60% of prescribed sets logged); post-study "would you keep using it without the plan?" | ≥ 70% follow the plan |
| Is verification fair? | % of finishes failing location; % no-signal; complaints | < 5% false fails |
| Escape-hatch abuse | Emergency unlocks + rest swaps per user-week | < 0.5 |
| Retention | D7 / D14 active (opened app or logged workout) | D14 ≥ 40% |
| Willingness to pay | Day-14 real paywall/pre-order: $4.99/mo or $29.99/yr (Stripe link) | ≥ 10% convert |
| Why people leave | 5-minute exit interview with everyone who revokes or goes inactive | Top 3 reasons |

Run it as **real usage, not surveys.** Interviews only to explain the numbers.

### Decision rules after 3 weeks
- D14 Screen Time retention < 40% → blocking is too aversive; test softer modes (time-limited unlock windows, partner accountability).
- Plan-follow < 50% → personalization isn't the hook; simplify to "any workout ≥ N min unlocks" and compete on UX/price, or rethink.
- Pay conversion < 3% → no business yet at this price; test campus-rec partnerships or a cheaper tier.

## Backlog (NOT in MVP — don't build until the loop is validated)
- Supabase auth + sync between web and iPhone (Week 2 if time; required before multi-device testers)
- Apple Health / HealthKit workout import as extra evidence
- Advanced AI plan adjustments (Claude via Edge Function)
- Accountability partners, friends, leaderboards, social challenges
- Gamification beyond streaks
- Push notifications (reminder on training days) — **first post-MVP item**, cheap and high-value
- Subscription monetization (StoreKit)
- Advanced analytics, nutrition, wearables
- Android (Digital Wellbeing APIs differ — separate feasibility study)
