// Choose the next calibrated, gender-aware question for the daily check-in.
import { BEHAVIOR_VOICE, MODELS, callClaude, cors, guard, readBody, extractJson } from './_claude.js';

export default async function handler(req, res) {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(404).send('not found');
  if (!guard(req)) return res.status(401).send('unauthorized');
  try {
    const { goals = [], turns = [], memory = null, stage = 'action' } = await readBody(req);
    const user =
      `Goals: ${JSON.stringify(goals).slice(0, 2000)}\n` +
      `Conversation so far (oldest first): ${JSON.stringify(turns).slice(0, 3000)}\n` +
      `What you remember about them (may include name + gender): ${JSON.stringify(memory).slice(0, 2000)}\n` +
      `Stage: ${stage}\n\n` +
      `Reflect their last answer if any, then ask ONE warm, specific question that moves them forward. ` +
      `Adapt to their gender if known. Don't repeat questions. If ~4-6 turns done, set is_final true.\n` +
      `Respond ONLY with minified JSON: {"question":string,"q_id":string,` +
      `"com_b_factor":"capability"|"opportunity"|"motivation"|"reflection","rationale":string,"is_final":boolean}`;
    const raw = await callClaude({ system: BEHAVIOR_VOICE, user, model: MODELS.smart, maxTokens: 300, temperature: 0.7 });
    const q = extractJson(raw);
    if (!q || !q.question) return res.status(200).json(fallback(turns));
    return res.status(200).json(q);
  } catch (e) {
    console.error('session-next', e);
    return res.status(200).json(fallback([]));
  }
}

function fallback(turns) {
  const n = Array.isArray(turns) ? turns.length : 0;
  const bank = [
    { q_id: 'open_today', question: 'How did today actually go for you?', com_b_factor: 'reflection' },
    { q_id: 'goal_progress', question: 'What did you actually do toward your goal today?', com_b_factor: 'reflection' },
    { q_id: 'obstacle', question: 'What got in the way, if anything?', com_b_factor: 'reflection' },
    { q_id: 'tomorrow_plan', question: "What's one tiny step you want to set up for tomorrow?", com_b_factor: 'opportunity' },
    { q_id: 'win', question: "What's one small thing you're a little proud of today?", com_b_factor: 'motivation' },
  ];
  const item = bank[Math.min(n, bank.length - 1)];
  return { ...item, rationale: 'fallback', is_final: n >= bank.length - 1 };
}
