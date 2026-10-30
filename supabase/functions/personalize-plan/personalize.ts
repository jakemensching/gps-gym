// Runtime-agnostic core of the personalize-plan function (no Deno APIs here),
// so it can be type-checked and tested under Node too.
import type Anthropic from "@anthropic-ai/sdk";
import { betaZodOutputFormat } from "@anthropic-ai/sdk/helpers/beta/zod";
import { z } from "zod";
import { EXERCISE_IDS, EXERCISES, GOALS, PATTERNS } from "./catalog.ts";

export const MAX_DESCRIPTION_CHARS = 600;

export const PersonalizationSchema = z.object({
  goals: z.array(z.enum(GOALS)),
  avoidExerciseIds: z.array(z.enum(EXERCISE_IDS)),
  focusPatterns: z.array(z.enum(PATTERNS)),
  coachNote: z.string(),
});
export type Personalization = z.infer<typeof PersonalizationSchema>;

export const RequestSchema = z.object({
  description: z.string().trim().min(1).max(MAX_DESCRIPTION_CHARS),
  profile: z.object({
    goals: z.array(z.enum(GOALS)),
    experience: z.enum(["beginner", "intermediate", "advanced"]),
    equipment: z.enum(["fullGym", "dumbbells", "bodyweight"]),
    mode: z.enum(["gym", "home"]),
    trainingDays: z.number().int().min(1).max(7),
    sessionMinutes: z.number().int().min(10).max(240),
  }),
});
export type PersonalizeRequest = z.infer<typeof RequestSchema>;

const SYSTEM_PROMPT = `You personalize strength-training plans for GPS-GYM, a fitness accountability app for college students and young adults.

A deterministic generator builds the actual program. You do not write workouts. You read the user's own description of what they want and translate it into adjustments the generator understands:

- goals: which of these the description implies, in addition to what they already picked: buildMuscle, getStronger, generalFitness, loseFat. Return an empty list if it adds nothing.
- avoidExerciseIds: exercises to leave out because the user mentions an injury, pain, a limitation, or a strong dislike. Only use IDs from the catalog. Be conservative: "my knee hurts on squats" means avoid the heavy squat variations, not every leg exercise. Return an empty list when nothing should be avoided.
- focusPatterns: movement patterns the user wants emphasized (for example "bigger arms" means biceps and triceps; "better posture" means horizontalPull and shoulderIsolation). Each one gets one extra set. Pick at most three. Return an empty list if there is no clear emphasis.
- coachNote: two or three short sentences, written to the user in second person, explaining how the plan reflects what they asked for. Be encouraging and concrete. Never promise a specific result, weight, or timeline. If they mention pain or an injury, say the plan works around it and that they should see a professional if it persists. No medical advice beyond that.

Exercise catalog (id: name, pattern):
${EXERCISES.map(([id, name, pattern]) => `${id}: ${name}, ${pattern}`).join("\n")}`;

export class RefusedError extends Error {}

export async function personalizePlan(client: Anthropic, req: PersonalizeRequest): Promise<Personalization> {
  const { profile } = req;
  // create() rather than parse(): parse() throws a generic error before we can see a
  // refusal (empty text), so check stop_reason first and validate the JSON ourselves.
  const message = await client.beta.messages.create({
    model: "claude-opus-5-5",
    max_tokens: 4000,
    // If a safety classifier declines, retry on Anthropic's recommended fallback model.
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    // A short extraction task: low effort keeps it fast and cheap.
    output_config: { effort: "low", format: betaZodOutputFormat(PersonalizationSchema) },
    system: SYSTEM_PROMPT,
    messages: [
      {
        role: "user",
        content:
          `Already selected goals: ${profile.goals.join(", ") || "none"}\n` +
          `Experience: ${profile.experience}\nEquipment: ${profile.equipment}\nTrains at: ${profile.mode}\n` +
          `Days per week: ${profile.trainingDays}\nSession length: ${profile.sessionMinutes} minutes\n\n` +
          `The user's description:\n<description>\n${req.description}\n</description>`,
      },
    ],
  });

  if (message.stop_reason === "refusal") throw new RefusedError("Request declined.");
  const text = message.content.flatMap((block) => (block.type === "text" ? [block.text] : [])).join("");
  if (message.stop_reason !== "end_turn" || !text) {
    throw new Error(`No structured output (stop_reason: ${message.stop_reason}).`);
  }
  return PersonalizationSchema.parse(JSON.parse(text));
}
