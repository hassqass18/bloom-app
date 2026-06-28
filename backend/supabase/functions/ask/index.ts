// Bloom — /ask : one warm follow-up question for a prompt section (Deep mode).
// Fast + cheap (Haiku). Returns { question }. Never blocks the client save.
import { BLOOM_VOICE, callClaude, handleCors, json, MODELS } from "../_shared/anthropic.ts";

Deno.serve(async (req) => {
  const pre = handleCors(req);
  if (pre) return pre;
  try {
    const { section, text, mood } = await req.json();
    if (!text || typeof text !== "string") return json({ question: null });

    const moodHint = mood ? `Their mood today is ${mood}/5. If low, soften further.` : "";
    const user =
      `The person just wrote this under the "${section ?? "journal"}" section:\n"""${text}"""\n` +
      `${moodHint}\nAsk ONE gentle, curious follow-up (max ~18 words). ` +
      `If nothing warm is worth asking, reply exactly with: SKIP`;

    const out = await callClaude({
      system: BLOOM_VOICE,
      user,
      model: MODELS.fast,
      maxTokens: 80,
      temperature: 0.8,
    });

    const question = out === "SKIP" || out.length === 0 ? null : out;
    return json({ question });
  } catch (err) {
    // Graceful no-op: AI must never break the experience.
    console.error("ask error", err);
    return json({ question: null });
  }
});
