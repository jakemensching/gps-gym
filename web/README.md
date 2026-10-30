# GPS-GYM Web

The web form of GPS-GYM: onboarding, plan generator, workout logging, gym check-in, progress. App blocking is iPhone-only.

```bash
npm install   # .npmrc sets legacy-peer-deps (vitest optional peer quirk)
npm run dev   # http://localhost:3000
npm test      # core logic tests (mirror of ios/Packages/GPSGymCore)
npm run build
```

- `src/lib/core/` — generator, progression, verification, enforcement. **Keep in sync with the Swift package.**
- `src/lib/store.ts` — localStorage store (Supabase sync is a Week 2 task).
- `src/components/` — screens.

Built on Next.js 16 — see `AGENTS.md`: read `node_modules/next/dist/docs/` before changing framework-level code.
