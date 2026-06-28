// Turn a broad wish into a DEFINITE goal + tiny if-then steps (tasks).
import { BEHAVIOR_VOICE, MODELS, callClaude, cors, guard, readBody, extractJson } from './_claude.js';

export default async function handler(req, res) {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(404).send('not found');
  if (!guard(req)) return res.status(401).send('unauthorized');
  try {
    const { wish, context } = await readBody(req);
    if (!wish) return res.status(400).json({ error: 'wish required' });
    const user =
      `The person said their wish is: "${wish}".\n` +
      (context ? `About them: ${JSON.stringify(context).slice(0, 2000)}\n` : '') +
      `Help them make it DEFINITE and break it into 2-4 TINY if-then steps (tasks) drawn from THEIR wish.\n` +
      `Respond ONLY with minified JSON: {"definite_statement":string,"domain":string,"metric":string,` +
      `"target_value":number|null,"unit":string,"cadence":"daily"|"weekly"|"monthly","value_anchor":string,` +
      `"obstacles":string[],"steps":[{"title":string,"if_cue":string,"then_action":string,"anchor_routine":string,"bct_id":string}]}`;
    const raw = await callClaude({ system: BEHAVIOR_VOICE, user, model: MODELS.smart, maxTokens: 700, temperature: 0.5 });
    const plan = extractJson(raw);
    if (!plan) return res.status(200).json(fallback(wish));
    return res.status(200).json(plan);
  } catch (e) {
    console.error('plan-build', e);
    const { wish } = await readBody(req).catch(() => ({ wish: 'your goal' }));
    return res.status(200).json(fallback(wish || 'your goal'));
  }
}

function fallback(wish) {
  return {
    definite_statement: `Make steady, measurable progress on: ${wish}`,
    domain: 'growth', metric: 'days I take one small action', target_value: 5,
    unit: 'days/week', cadence: 'daily', value_anchor: 'the person I am becoming',
    obstacles: ['forgetting', 'low-energy days'],
    steps: [{ title: 'One tiny action each day', if_cue: 'After my morning tea',
      then_action: 'I do one small thing toward this goal', anchor_routine: 'morning tea', bct_id: '1.4_action_planning' }],
  };
}
