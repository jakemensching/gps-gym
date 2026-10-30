# iOS App-Blocking Feasibility & Technical Risks

_Researched 2026-10-30. Sources at the bottom. Forum reports are anecdotes, not Apple policy — treat them as risk signals._

## Verdict: ✅ Feasible — with one schedule-critical bottleneck

Apple's Screen Time APIs (iOS 16+) let a third-party app, with the user's explicit consent, lock apps the user picks and unlock them from code. That's exactly our loop. Many shipping apps (Opal, one sec, and 10+ gym blockers) prove App Review accepts this category.

## How it works (and what we built)

| Piece | Framework | What it does in GPS-GYM |
|---|---|---|
| Consent | **FamilyControls** `AuthorizationCenter.requestAuthorization(for: .individual)` | System sheet, confirmed with Face ID/passcode. Fails in the Simulator. |
| App picking | **FamilyControls** `FamilyActivityPicker` | User picks apps/categories. We get **opaque tokens** — we never learn which apps (privacy by design). |
| Locking | **ManagedSettings** `ManagedSettingsStore.shield` | Shields persist across launches and reboots until we clear them. |
| Unlocking | `store.clearAllSettings()` from the main app | Called when a workout verifies. Instant. |
| Re-locking each day | **DeviceActivity** monitor extension | Repeating 00:00–23:59 schedule; `intervalDidStart` re-applies the shield on training days **even if the app is never opened**. |
| Shield UI | **ManagedSettingsUI** shield-configuration extension | Custom "Earn your scroll" screen. |

Shared state (selection + `EnforcementState`) lives in an **App Group** so the app and extensions make the exact same decision (`EnforcementState.shouldShield`).

## What Apple does NOT allow (design constraints)

1. **Users can always revoke.** With `.individual` authorization, the user can turn us off in Settings → Screen Time at any time; `denyAppRemoval` isn't a guarantee. → We're a **commitment device**, not a jail. We say so in the UI, and we measure revocation as a key metric.
2. **No bundle-ID blocking.** Only picker tokens. We can't pre-select TikTok for the user.
3. **No background GPS trickery needed or wanted.** We use When-In-Use location only during workouts. No "Always" permission (App Review scrutiny, battery, privacy).
4. **DeviceActivity intervals must be ≥ 15 minutes.** Fine for daily windows; the Blocking Lab test uses 16 minutes.
5. **Extensions are memory-capped (~6 MB).** The monitor extension only reads a small JSON blob and flips a shield. No SwiftData, no networking.
6. **Simulator can't authorize Screen Time.** All blocking tests need a physical iPhone. Everything else (onboarding, plans, logging, progress) works in the Simulator — onboarding has a "Set up blocking later" path for this.
7. **~50 app tokens per store** (developer reports). Irrelevant for us (users pick 2–6 apps).

## 🚨 The bottleneck: Family Controls **Distribution** entitlement

- **Development** entitlement: available immediately with a paid Apple Developer account. Lets you build and run on your own registered iPhones from Xcode. **Our POC needs only this.**
- **Distribution** entitlement: required for **TestFlight and the App Store**. Requested per bundle ID — we have **3** (app, monitor extension, shield extension) and should request all three.
- Turnaround is unpredictable. 2026 forum reports range from quick approvals to **4+ weeks** with no response, plus approvals that didn't propagate to provisioning profiles.

**This is the single biggest threat to a 14–21 day TestFlight beta.**

### Mitigation plan
1. **Day 1:** enroll in the Apple Developer Program ($99/yr) if not already, register the 3 bundle IDs + App Group, and **submit the distribution request for all 3 immediately.** Describe the use case plainly: "self-directed screen-time commitment app; user picks apps to restrict until they complete a workout; user can revoke at any time."
2. **If not approved by ~Day 12, beta anyway (legit, no workarounds):**
   - **Direct installs:** register testers' iPhones (up to 100 devices/year) and install development-signed builds from Xcode at a campus "install session." Fully supported by Apple, just manual.
   - **Web app:** testers without a registered iPhone use the web version for plan + logging + streaks (no blocking) — this also gives us a control group.
3. Do **not** ship a build that hides or fakes the entitlement. Not worth an account ban.

## Other technical risks (ranked)

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | Distribution entitlement delay | High | High | See above. |
| 2 | `intervalDidStart` occasionally not firing | Medium | Medium | App re-syncs shield on every foreground; shields persist anyway, so a missed fire only delays a re-lock. Measure in beta. |
| 3 | Users revoke Screen Time access | High | Medium | It's their right. Detect on foreground, show a clear warning, track as churn signal. |
| 4 | Indoor GPS drift → false "not at gym" | Medium | High (rage-quit) | Benefit-of-the-doubt with fix accuracy; no-signal ≠ failure (low-trust pass); "Save without unlocking" + rest-day swap + emergency unlock. |
| 5 | Location spoofing / gaming | Low | Low | Target user is honest-but-weak-willed. Faking costs more effort than a 25-minute workout. Trust level is logged for analysis. |
| 6 | App Review rejection (guideline 5.5 / 2.5.1 framing) | Low–Med | High | Clear self-control framing, prominent user control, no covert monitoring, privacy-light location. |
| 7 | Data loss (local-only) | Low | Medium | Atomic file writes with file protection; Supabase backup in Week 2. |

## Sources
- [Family controls distribution request (timeline info) — Apple Developer Forums](https://developer.apple.com/forums/thread/820811)
- [How to Get the Apple Family Controls Entitlement — newly.app](https://newly.app/how-to/family-controls-entitlement)
- [Family Controls Entitlement Blocking App Store Release — Apple Developer Forums](https://developer.apple.com/forums/thread/824972)
- [Family Controls entitlement missing from Distribution Provisioning Profile — Apple Developer Forums](https://developer.apple.com/forums/thread/829311)
- [FamilyControls individual authorization: no way to detect revocation while backgrounded — Apple Developer Forums](https://developer.apple.com/forums/thread/820796)
- [does FamilyControlsMember.individual mode prevent user from disabling the block? — Apple Developer Forums](https://developer.apple.com/forums/thread/708000)
- [DeviceActivityMonitor intervalDidEnd not firing for non-repeating timed unlock — Apple Developer Forums](https://developer.apple.com/forums/thread/820956)
- [ManagedSettings can't shield Messages and other system apps — Apple Developer Forums](https://developer.apple.com/forums/thread/729891)
- [Building with Screen Time and Family Controls — drobinin.com](https://drobinin.com/consulting/screen-time-family-controls/building-with-screen-time-and-family-controls/)
- [AuthorizationCenter.requestAuthorization(for:) — Apple docs](https://developer.apple.com/documentation/familycontrols/authorizationcenter/requestauthorization(for:))
- [ManagedSettings — Apple docs](https://developer.apple.com/documentation/managedsettings)
- [DeviceActivityMonitor — Apple docs](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor)
