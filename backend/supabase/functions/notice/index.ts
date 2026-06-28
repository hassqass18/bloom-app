// Bloom — /notice : weekly "What I'm noticing" insight card.
// Reads the user's own recent entries (RLS-scoped via the caller's JWT), asks
// Claude for 3-5 gentle observations, caches the result in ai_outputs.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { BLOOM_VOICE, callClaude, handleCors, json, MODELS } from "../_shared/anthropic.ts";

Deno.serve(async (req) => {
  const pre = handleCors(req);
  if (pre) return pre;
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const since = new Date(Date.now() - 7 * 864e5).toISOString().slice(0, 10);

    // RLS guarantees these are only the caller's rows.
    const [{ data: journal }, { data: emotions }, { data: money }] = await Promise.all([
      supabase.from("journal_entries").select("kind,payload,day").gte("day", since).is("deleted_at", null),
      supabase.from("emotions").select("emotion,valence,day").gte("day", since).is("deleted_at", null),
      supabase.from("money_entries").select("direction,amount,category,day").gte("day", since).is("deleted_at", null),
    ]);

    const corpus = JSON.stringify({ journal, emotions, money }).slice(0, 12000);
    const user =
      `Here is the person's last 7 days of entries (their own words and logs):\n${corpus}\n\n` +
      `Write 3-5 short, gentle observations a kind friend might notice — patterns, returns, small wins. ` +
      `One per line, each starting with "• ". Observational only, never advice. ` +
      `If there is a clear link between a low mood day and higher spending, you may gently note it. ` +
      `If there is too little to notice, reply with: • Not much yet — keep going, your week is still unfolding 🌸`;

    const text = await callClaude({ system: BLOOM_VOICE, user, model: MODELS.smart, maxTokens: 400, temperature: 0.7 });
    const bullets = text.split("\n").map((l) => l.replace(/^[•\-\*]\s*/, "").trim()).filter(Boolean);

    const period = weekKey(new Date());
    await supabase.from("ai_outputs").insert({ kind: "insight", period, content: { bullets }, model: MODELS.smart });

    return json({ period, bullets });
  } catch (err) {
    console.error("notice error", err);
    return json({ bullets: [], error: "unavailable" }, 200);
  }
});

function weekKey(d: Date): string {
  const dt = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dayNum = (dt.getUTCDay() + 6) % 7;
  dt.setUTCDate(dt.getUTCDate() - dayNum + 3);
  const firstThu = new Date(Date.UTC(dt.getUTCFullYear(), 0, 4));
  const week = 1 + Math.round(((dt.getTime() - firstThu.getTime()) / 864e5 - 3 + ((firstThu.getUTCDay() + 6) % 7)) / 7);
  return `${dt.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}
