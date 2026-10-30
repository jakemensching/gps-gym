# AI Goal Personalization

Users can describe their goal in their own words ("gain 5 lbs of muscle, bigger arms, my left knee hurts on squats").
Claude turns that into **safe adjustments** to the deterministic plan:

| Field | Effect |
|---|---|
| `goals` | Added to the goals the user tapped |
| `avoidExerciseIds` | Those exercises are left out (injuries, dislikes) |
| `focusPatterns` | Up to 3 movement patterns get +1 set (e.g. biceps, triceps) |
| `coachNote` | 2–3 sentences shown on the plan, no promised results |

Claude never writes workouts. The generator still builds every plan, so a bad AI answer can't produce a dangerous program, and the browser drops any value it doesn't recognize.

## Why a server function?
The Anthropic API key **must not** be in the website: GitHub Pages is public, and anyone could copy the key and spend your money. The key lives only in a Supabase Edge Function (`supabase/functions/personalize-plan`).

## Turn it on (~10 minutes)
1. Get an API key at https://console.anthropic.com → API Keys.
2. Create a free Supabase project at https://supabase.com, then install the CLI (`brew install supabase/tap/supabase`).
3. From the repo root:
   ```bash
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
   supabase functions deploy personalize-plan
   ```
4. In GitHub → repo **Settings → Secrets and variables → Actions → Variables**, add:
   - `PLAN_AI_URL` = `https://YOUR_PROJECT_REF.supabase.co/functions/v1/personalize-plan`
   - `SUPABASE_ANON_KEY` = your project's anon/public key (Supabase → Project Settings → API)
5. Re-run the **Deploy web app to GitHub Pages** workflow (Actions tab → Run workflow).

Until then, the app says "AI personalization is coming soon" and uses the tapped goals. Nothing breaks.

## Model & cost
- `claude-opus-5-5`, effort `low` (a short extraction task), structured JSON output.
- Server-side refusal fallback (`fallbacks: "default"`) is on: if a safety classifier declines, the API retries on Anthropic's recommended fallback model.
- Roughly 1–2K input tokens + a few hundred output tokens per plan: about a cent per request.

## ⚠️ Before a public launch
The endpoint is callable by anyone who finds the URL (CORS only blocks other *websites*). Fine for 10–50 testers; before launch, require Supabase sign-in and add a per-user rate limit.

## Verified so far
Type-checked against `@anthropic-ai/sdk` 1.3.0 and exercised with a mocked HTTP layer: correct request shape, successful parse, refusal → HTTP 422, invalid model output rejected. **It hasn't been called against the live API yet**, because that needs your key.
