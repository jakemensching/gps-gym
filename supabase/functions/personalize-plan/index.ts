// Supabase Edge Function: POST { description, profile } → Personalization JSON.
// The Claude API key stays here, server-side. Deploy:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//   supabase functions deploy personalize-plan
// See docs/AI-PERSONALIZATION.md.
import Anthropic from "@anthropic-ai/sdk";
import { personalizePlan, RefusedError, RequestSchema } from "./personalize.ts";

const client = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

// Not real security (anyone can call the URL), but keeps other websites from using it in browsers.
const ALLOWED_ORIGIN = Deno.env.get("ALLOWED_ORIGIN") ?? "https://jakemensching.github.io";

const cors = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const parsed = RequestSchema.safeParse(await req.json().catch(() => null));
  if (!parsed.success) return json({ error: "Invalid request." }, 400);

  try {
    return json(await personalizePlan(client, parsed.data));
  } catch (error) {
    if (error instanceof RefusedError) return json({ error: "We couldn't personalize that description." }, 422);
    if (error instanceof Anthropic.RateLimitError) return json({ error: "Too many requests. Try again in a minute." }, 429);
    if (error instanceof Anthropic.APIError) {
      console.error("Claude API error", error.status, error.message);
      return json({ error: "AI service error." }, 502);
    }
    console.error(error);
    return json({ error: "Something went wrong." }, 500);
  }
});
