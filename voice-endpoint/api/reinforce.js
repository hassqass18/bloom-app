// The ethical "push": reflect real data back with warmth (SDT, no guilt/streaks).
import { BEHAVIOR_VOICE, MODELS, callClaude, cors, guard, readBody, extractJson } from './_claude.js';

export default async function handler(req, res) {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(404).send('not found');
  if (!guard(req)) return res.status(401).send('unauthorized');
  try {
    const { logs = [], progress = {}, stage = 'action' } = await readBody(req);
    const user =
      `Recent logs: ${JSON.stringify(logs).slice(0, 2500)}\nProgress: ${JSON.stringify(progress).slice(0, 1500)}\nStage: ${stage}\n\n` +
      `Write ONE short, warm message from this real data. Celebrate progress specifically, or if they lapsed, ` +
      `be compassionate and offer one tiny re-start — never guilt, never streaks. Two sentences max.\n` +
      `Respond ONLY with minified JSON: {"kind":"celebrate"|"nudge"|"replan"|"insight","text":string}`;
    const raw = await callClaude({ system: BEHAVIOR_VOICE, user, model: MODELS.fast, maxTokens: 200, temperature: 0.8 });
    const r = extractJson(raw);
    if (!r || !r.text) return res.status(200).json(fallback(progress));
    return res.status(200).json(r);
  } catch (e) {
    console.error('reinforce', e);
    return res.status(200).json(fallback({}));
  }
}

function fallback(progress) {
  const done = Number(progress?.doneToday ?? 0);
  return done > 0
    ? { kind: 'celebrate', text: "You showed up today — another quiet vote for who you're becoming. 🌱" }
    : { kind: 'replan', text: "Today was a soft day, and that's okay. What's the smallest possible step for tomorrow? 💜" };
}
