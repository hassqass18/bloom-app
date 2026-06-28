// Bloom — /plan-build : turn a broad wish into a DEFINITE goal + tiny if-then steps.
// Grounded in Goal-Setting Theory (specific+measurable+challenging), WOOP (obstacles),
// Tiny Habits (shrink + anchor), and BCTTv1 (tag each step with a technique id).
import { BEHAVIOR_VOICE, callClaude, handleCors, json, MODELS } from "../_shared/anthropic.ts";

Deno.serve(async (req) => {
  const pre = handleCors(req);
  if (pre) return pre;
  try {
    const { wish, context } = await req.json().catch(() => ({ wish: "" }));
    if (!wish || typeof wish !== "string") return json({ error: "wish required" }, 400);

    const user =
      `The person said their wish is: "${wish}".\n` +
      (context ? `Context about them: ${JSON.stringify(context).slice(0, 2000)}\n` : "") +
      `Help them make it DEFINITE and break it into 2-4 TINY if-then steps.\n` +
      `Respond with ONLY minified JSON (no prose, no code fences) matching:\n` +
      `{"definite_statement":string,"domain":string,"metric":string,` +
      `"target_value":number|null,"unit":string,"cadence":"daily"|"weekly"|"monthly",` +
      `"value_anchor":string,"obstacles":string[],` +
      `"steps":[{"title":string,"if_cue":string,"then_action":string,` +
      `"anchor_routine":string,"bct_id":string}]}\n` +
      `Make the definite_statement specific, measurable and time-bound. Keep each ` +
      `step comically small. Use the person's own language.`;

    const raw = await callClaude({
      system: BEHAVIOR_VOICE,
      user,
      model: MODELS.smart,
      maxTokens: 700,
      temperature: 0.5,
    });

    const plan = extractJson(raw);
    if (!plan) return json(fallback(wish), 200);
    return json(plan);
  } catch (err) {
    console.error("plan-build error", err);
    const body = await safeWish(req);
    return json(fallback(body), 200);
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

async function safeWish(_req: Request): Promise<string> {
  return "your goal";
}

// Deterministic fallback so the client always gets a usable plan.
function fallback(wish: string): Record<string, unknown> {
  return {
    definite_statement: `Make steady, measurable progress on: ${wish}`,
    domain: "growth",
    metric: "days I take one small action",
    target_value: 5,
    unit: "days/week",
    cadence: "daily",
    value_anchor: "the person I'm becoming",
    obstacles: ["forgetting", "low energy days"],
    steps: [
      {
        title: "One tiny action each day",
        if_cue: "After my morning tea",
        then_action: "I do one small thing toward this goal",
        anchor_routine: "morning tea",
        bct_id: "1.4_action_planning",
      },
    ],
  };
}
