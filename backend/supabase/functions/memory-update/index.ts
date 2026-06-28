// Bloom — /memory-update : roll the longitudinal "pocket therapist" memory forward.
// This is the explicit anti-ChatGPT feature: Bloom remembers the whole person across
// time. Merges the prior memory with the latest session + logs into a compact profile.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { BEHAVIOR_VOICE, callClaude, handleCors, json, MODELS } from "../_shared/anthropic.ts";

Deno.serve(async (req) => {
  const pre = handleCors(req);
  if (pre) return pre;
  try {
    const { prior = null, session = null, logs = [] } =
      await req.json().catch(() => ({}));

    const user =
      `Prior memory of this person: ${JSON.stringify(prior).slice(0, 3000)}\n` +
      `Newest session: ${JSON.stringify(session).slice(0, 2500)}\n` +
      `Recent logs: ${JSON.stringify(logs).slice(0, 2000)}\n\n` +
      `Update a compact, respectful longitudinal memory. Keep what still matters, ` +
      `fold in what's new, drop stale detail. Never store sensitive trauma verbatim — ` +
      `summarize tone, not painful content.\n` +
      `Respond with ONLY minified JSON: ` +
      `{"summary":{"who":string,"goals":string,"recent":string},` +
      `"values":string[],"patterns":string[]}`;

    const raw = await callClaude({
      system: BEHAVIOR_VOICE,
      user,
      model: MODELS.fast,
      maxTokens: 500,
      temperature: 0.5,
    });

    const mem = extractJson(raw);
    if (!mem) return json(prior ?? empty(), 200);

    // Persist if we have an authenticated caller (RLS-scoped upsert).
    try {
      const authHeader = req.headers.get("Authorization") ?? "";
      if (authHeader) {
        const supabase = createClient(
          Deno.env.get("SUPABASE_URL")!,
          Deno.env.get("SUPABASE_ANON_KEY")!,
          { global: { headers: { Authorization: authHeader } } },
        );
        await supabase.from("memory_profile").upsert(
          {
            summary: mem.summary ?? {},
            core_values: mem.values ?? [],
            patterns: mem.patterns ?? [],
          },
          { onConflict: "user_id" },
        );
      }
    } catch (e) {
      console.error("memory persist skipped", e);
    }

    return json(mem);
  } catch (err) {
    console.error("memory-update error", err);
    return json(empty(), 200);
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

function empty(): Record<string, unknown> {
  return { summary: {}, values: [], patterns: [] };
}
