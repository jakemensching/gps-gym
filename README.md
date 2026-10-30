# GPS-GYM 🏋️🔒

**Want to scroll? Earn it.** A personalized training plan + your distracting apps locked on training days until your workout is verified.

Two forms, one product:
- **iPhone app** (`ios/`, SwiftUI) — the full experience, including Screen Time app blocking.
- **Web app** (`web/`, Next.js) — plan, workout logging, progress. No app blocking (browsers can't do that).

## Run the web app (any computer)
```bash
cd web
npm install
npm run dev
```
Open http://localhost:3000 → "Build my plan". Tests: `npm test`.

## Run the iPhone app (Mac)
```bash
brew install xcodegen
cd ios && xcodegen generate && open GPSGym.xcodeproj
```
Pick an iPhone Simulator and hit Run. In the Simulator, choose **"Set up blocking later"** during onboarding — Screen Time only works on a real iPhone. To test blocking, follow [`docs/POC-BLOCKING.md`](docs/POC-BLOCKING.md).

Core logic tests: `swift test --package-path ios/Packages/GPSGymCore`

## Docs
- [`CHECKLIST.md`](CHECKLIST.md) — status, blockers, next up
- [`docs/FEASIBILITY.md`](docs/FEASIBILITY.md) — Screen Time research, entitlement bottleneck, risks
- [`docs/PRODUCT.md`](docs/PRODUCT.md) — MVP, competitors, validation metrics, backlog
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — 14–21 day plan
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — stack, layout, enforcement loop, verification rules
