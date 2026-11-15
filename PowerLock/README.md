# PowerLock: HTML prototype (current build)

A clickable, single-file HTML version of the PowerLock iOS app as it's built right now
(SwiftUI, November 2026). Open `index.html` in any browser. It needs no build step and no install.

On a computer it shows a phone frame with a list of every screen on the left. On a phone
it fills the screen, and the **Screens** button opens that list.

## What's in it

- **Onboarding (16 pages):** intro, age, gender, bodyweight, goal, goal length, experience,
  equipment, screen time, the "years on your phone" reveal, pick your plan, set your week,
  gym, apps to lock, daily schedule, free trial
- **Paywall:** yearly and monthly plans
- **Today:** locked, unlocked, rest day and emergency-unlock states
- **Session:** not at the gym, running, paused (GPS lost) and verified
- **Plan:** goal card, this week, how it progresses, and the workout detail with exercise swaps
- **Progress:** streak, calendar, bodyweight log, and the history of unlocks and rule changes
- **Settings**, **emergency unlock** (with the one-minute wait) and the **lock screen**

## Prototype shortcuts

- The session clock runs 60× fast, so a full 60-minute verify takes about a minute.
- The emergency-unlock wait runs 6× fast.
- GPS, Screen Time, notifications and payments are simulated. Nothing is saved.

## Viewing it on GitHub Pages

If GitHub Pages is on for this repo, the prototype is at
`https://<user>.github.io/<repo>/PowerLock-HTML/`.
