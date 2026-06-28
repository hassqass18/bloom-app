// Bloom — /companion-chat : fast, memory-aware reflection for the voice/companion
// loop. Uses Haiku for low latency so spoken replies feel real-time. (Upgrade
// path: stream tokens via SSE + a streaming TTS for sub-second time-to-first-audio.)
import { BEHAVIOR_VOICE, callClaude, handleCors, json, MODELS } from "../_shared/anthropic.ts";

Deno.serve(async (req) => {
  const pre = handleCors(req);
  if (pre) return pre;
  try {
    const { message = "", memory = null, history = [] } =
      await req.json().catch(() => ({}));
    if (!message) return json({ reply: "" }, 200);

    const user =
      `What you remember about them: ${JSON.stringify(memory).slice(0, 2000)}\n` +
      `Recent exchange: ${JSON.stringify(history).slice(0, 2000)}\n` +
      `They just said: "${message}"\n\n` +
      `Reply as Bloom — one or two warm, human sentences. Reflect what they said ` +
      `(Motivational Interviewing), reference what you remember when relevant, and ` +
      `if it fits, ask ONE gentle follow-up. Spoken aloud, so keep it natural.`;

    const reply = await callClaude({
      system: BEHAVIOR_VOICE,
      user,
      model: MODELS.fast,
      maxTokens: 160,
      temperature: 0.8,
    });
    return json({ reply: reply.trim() });
  } catch (err) {
    console.error("companion-chat error", err);
    return json({ reply: "" }, 200);
  }
});
