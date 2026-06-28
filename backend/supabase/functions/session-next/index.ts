// Bloom — /session-next : choose the next CALIBRATED question for the daily check-in.
// Grounded in Motivational Interviewing (OARS), Socratic questioning, and adaptive
// measurement (CAT/JITA-EMA): pick the next most-informative, stage-matched question
// given prior answers, the person's goals, and their longitudinal memory.
import { BEHAVIOR_VOICE, callClaude, handleCors, json, MODELS } from "../_shared/anthropic.ts";

Deno.serve(async (req) => {
  const pre = handleCors(req);
  if (pre) return pre;
  try {
    const { goals = [], turns = [], memory = null, stage = "action" } =
      await req.json().catch(() => ({}));

    const user =
      `Goals: ${JSON.stringify(goals).slice(0, 2000)}\n` +
      `Conversation so far this session (oldest first): ${JSON.stringify(turns).slice(0, 3000)}\n` +
      `What you remember about them: ${JSON.stringify(memory).slice(0, 2000)}\n` +
      `Their current change stage: ${stage}\n\n` +
      `Choose the SINGLE next question to ask. Reflect their last answer first if there ` +
      `is one, then ask one open, warm, specific question that moves them forward ` +
      `(toward a definite goal, surfacing an obstacle, or evoking their own reason to ` +
      `change). Do not repeat questions already asked. If the conversation has covered ` +
      `enough (about 4-6 turns) or they seem done, set is_final true.\n` +
      `Respond with ONLY minified JSON: ` +
      `{"question":string,"q_id":string,"com_b_factor":"capability"|"opportunity"|"motivation"|"reflection","rationale":string,"is_final":boolean}`;

    const raw = await callClaude({
      system: BEHAVIOR_VOICE,
      user,
      model: MODELS.smart,
      maxTokens: 300,
      temperature: 0.7,
    });

    const q = extractJson(raw);
    if (!q || !q.question) return json(fallback(turns), 200);
    return json(q);
  } catch (err) {
    console.error("session-next error", err);
    return json(fallback([]), 200);
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

function fallback(turns: unknown[]): Record<string, unknown> {
  const n = Array.isArray(turns) ? turns.length : 0;
  const bank = [
    { q_id: "open_today", question: "How did today actually go for you?", com_b_factor: "reflection" },
    { q_id: "goal_progress", question: "What did you actually do toward your goal today?", com_b_factor: "reflection" },
    { q_id: "obstacle", question: "What got in the way, if anything?", com_b_factor: "reflection" },
    { q_id: "tomorrow_plan", question: "What's one tiny step you want to set up for tomorrow?", com_b_factor: "opportunity" },
    { q_id: "win", question: "What's one small thing you're a little proud of today?", com_b_factor: "motivation" },
  ];
  const item = bank[Math.min(n, bank.length - 1)];
  return { ...item, rationale: "static fallback", is_final: n >= bank.length - 1 };
}
