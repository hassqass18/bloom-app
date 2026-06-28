// Bloom — /reinforce : the ethical "push". Reflect the person's real data back with
// warmth. Grounded in Self-Determination Theory + ethical reinforcement: celebrate
// progress, treat lapses as data (compassionate re-plan), never guilt, never streaks.
import { BEHAVIOR_VOICE, callClaude, handleCors, json, MODELS } from "../_shared/anthropic.ts";

Deno.serve(async (req) => {
  const pre = handleCors(req);
  if (pre) return pre;
  try {
    const { logs = [], progress = {}, stage = "action" } =
      await req.json().catch(() => ({}));

    const user =
      `Recent logs: ${JSON.stringify(logs).slice(0, 2500)}\n` +
      `Goal progress: ${JSON.stringify(progress).slice(0, 1500)}\n` +
      `Stage: ${stage}\n\n` +
      `Write ONE short, warm message based on this real data. If they made progress, ` +
      `celebrate it specifically and connect it to who they're becoming. If they ` +
      `lapsed, be compassionate and offer one tiny re-start — never guilt, never ` +
      `mention streaks. Two sentences max.\n` +
      `Respond with ONLY minified JSON: ` +
      `{"kind":"celebrate"|"nudge"|"replan"|"insight","text":string}`;

    const raw = await callClaude({
      system: BEHAVIOR_VOICE,
      user,
      model: MODELS.fast,
      maxTokens: 200,
      temperature: 0.8,
    });

    const r = extractJson(raw);
    if (!r || !r.text) return json(fallback(progress), 200);
    return json(r);
  } catch (err) {
    console.error("reinforce error", err);
    return json(fallback({}), 200);
  }
});

function extractJson(s: string): Record<string, unknown> | null {
  try {
    const m = s.match(/\{[\s\S]*\}/);
    return m ? JSON.parse(m[0]) : null;
  } catch {
    return null;
  }
}

function fallback(progress: Record<string, unknown>): Record<string, unknown> {
  const done = Number((progress?.done as number) ?? 0);
  if (done > 0) {
    return { kind: "celebrate", text: "You showed up today — that's another quiet vote for who you're becoming. 🌱" };
  }
  return { kind: "replan", text: "Today was a soft day, and that's okay. What's the smallest possible step for tomorrow? 💜" };
}
