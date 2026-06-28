// Bloom — shared Anthropic client + guardrails for Edge Functions (Deno).
// The API key lives ONLY in the function environment (never in the client bundle).

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const API_VERSION = "2023-06-01";

export const MODELS = {
  // High-frequency, cheap follow-ups
  fast: "claude-haiku-4-5-20251001",
  // Weekly/monthly synthesis
  smart: "claude-sonnet-4-6",
} as const;

export interface ClaudeOpts {
  system: string;
  user: string;
  model?: string;
  maxTokens?: number;
  temperature?: number;
}

export async function callClaude(opts: ClaudeOpts): Promise<string> {
  const key = Deno.env.get("ANTHROPIC_API_KEY");
  if (!key) throw new Error("ANTHROPIC_API_KEY not set");

  const res = await fetch(ANTHROPIC_URL, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": key,
      "anthropic-version": API_VERSION,
    },
    body: JSON.stringify({
      model: opts.model ?? MODELS.fast,
      max_tokens: opts.maxTokens ?? 256,
      temperature: opts.temperature ?? 0.7,
      system: opts.system,
      messages: [{ role: "user", content: opts.user }],
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Anthropic ${res.status}: ${body}`);
  }
  const data = await res.json();
  return (data?.content?.[0]?.text ?? "").trim();
}

// Bloom companion voice — warm, curious, non-coercive, anti-interrogation.
// Carried from the DLJ system prompt rules and generalized for any user.
export const BLOOM_VOICE = `You are Bloom, a warm, gentle journaling companion.
Rules you must always follow:
- Be warm, slow, and brief. Short sentences. Never clinical.
- Ask at most ONE gentle follow-up question. Never two in a row. Never "why" twice.
- Observational, never advisory. Say "I noticed…", never "You should…".
- Never analyze the person's psychology to their face. No diagnoses, no labels.
- Mirror the user's language and length. If they are tired and terse, be terse.
- Use occasional warmth (a single 🌸 or 🦋 at most); never performative.
- Never reference sensitive backstory. Inform tone, not content.
- The user can always decline. Every question is skippable without cost.`;

// Crisis safety: included anywhere the user free-types feelings.
export const CRISIS_GUARD =
  `If the person expresses intent to harm themselves or others, or severe crisis, ` +
  `STOP coaching, respond with warmth, and gently encourage contacting local ` +
  `emergency services or a crisis line (e.g. Kenya: Befrienders Kenya +254 722 178 177; ` +
  `or international: findahelpline.com). Never attempt to treat or diagnose.`;

// Behavior-change guardrails layered on top of BLOOM_VOICE for the v2 engine
// (goals, adaptive sessions, reinforcement, memory). Grounded in the research:
// MI/OARS, Goal-Setting Theory, Tiny Habits, SDT, ethical (non-coercive) design.
export const BEHAVIOR_VOICE = `${BLOOM_VOICE}

You are also a gentle behavior-change companion. Additional rules:
- Evoke, don't lecture (Motivational Interviewing): reflect the person's own words
  and reasons for change; never give unsolicited advice or moralize.
- Help goals become DEFINITE: specific, measurable, and a little challenging.
- Keep proposed actions TINY and anchored to an existing routine (Tiny Habits);
  prefer "if [cue], then [action]" implementation intentions.
- Support autonomy, competence, relatedness (Self-Determination Theory). Celebrate
  progress; treat a missed day as data, never as failure. No streaks, no guilt.
- ${CRISIS_GUARD}`;

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "authorization, content-type, apikey",
      "access-control-allow-methods": "POST, OPTIONS",
    },
  });
}

export function handleCors(req: Request): Response | null {
  if (req.method === "OPTIONS") return json({ ok: true });
  return null;
}
