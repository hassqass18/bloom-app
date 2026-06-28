// Shared Claude client + Bloom voice/guardrails for the Vercel AI functions.
// Key stays server-side (ANTHROPIC_API_KEY env). Token-guarded like /api/tts.
const ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages';
const API_VERSION = '2023-06-01';

export const MODELS = {
  fast: 'claude-haiku-4-5-20251001',
  smart: 'claude-sonnet-4-6',
};

export const BEHAVIOR_VOICE = `You are Bloom — a warm, gentle behavior-change companion for men and women.
Rules:
- Warm, brief, human. Short sentences. Never clinical, never preachy.
- Evoke, don't lecture (Motivational Interviewing): reflect the person's own words and reasons.
- Make goals DEFINITE (specific, measurable, a little challenging) and break them into TINY, concrete "if [cue], then [action]" steps anchored to existing routines.
- Use the person's name and, when provided, their gender (male/female) to adapt tone and examples respectfully.
- Support autonomy, competence, relatedness. Celebrate progress; a missed day is data, never failure. No streaks, no guilt.
- If the person expresses self-harm or severe crisis, stop coaching, respond with warmth, and encourage contacting local emergency services or a crisis line. Never diagnose.`;

export function cors(res) {
  res.setHeader('access-control-allow-origin', '*');
  res.setHeader('access-control-allow-headers', 'content-type, x-bloom-token');
  res.setHeader('access-control-allow-methods', 'POST, OPTIONS');
}

export function guard(req) {
  const want = process.env.BLOOM_TTS_TOKEN || '';
  if (!want) return true;
  return req.headers['x-bloom-token'] === want;
}

export async function readBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  try { return JSON.parse(req.body || '{}'); } catch { return {}; }
}

export async function callClaude({ system, user, model, maxTokens = 500, temperature = 0.6 }) {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error('ANTHROPIC_API_KEY not set');
  const r = await fetch(ANTHROPIC_URL, {
    method: 'POST',
    headers: { 'x-api-key': key, 'anthropic-version': API_VERSION, 'content-type': 'application/json' },
    body: JSON.stringify({
      model: model || MODELS.smart,
      max_tokens: maxTokens,
      temperature,
      system,
      messages: [{ role: 'user', content: user }],
    }),
  });
  if (!r.ok) throw new Error(`Anthropic ${r.status}: ${(await r.text()).slice(0, 300)}`);
  const data = await r.json();
  return (data?.content?.[0]?.text ?? '').trim();
}

export function extractJson(s) {
  try { const m = s.match(/\{[\s\S]*\}/); return m ? JSON.parse(m[0]) : null; } catch { return null; }
}
