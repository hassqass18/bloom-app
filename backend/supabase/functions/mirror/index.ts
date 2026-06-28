// Bloom — /mirror : monthly private "Behind the scenes" behavioral mirror.
// Reads ALL of the caller's entries (RLS-scoped), produces a gentle markdown
// self-portrait. Read-only to the user; shared with no one. Cached in ai_outputs.
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

    const [{ data: journal }, { data: emotions }, { data: activities }] = await Promise.all([
      supabase.from("journal_entries").select("kind,payload,day").is("deleted_at", null).order("day", { ascending: false }).limit(400),
      supabase.from("emotions").select("emotion,valence,energy,day").is("deleted_at", null).order("day", { ascending: false }).limit(400),
      supabase.from("activities").select("title,tags,day").is("deleted_at", null).order("day", { ascending: false }).limit(400),
    ]);

    const corpus = JSON.stringify({ journal, emotions, activities }).slice(0, 16000);
    const user =
      `Below are the person's entries. Write a warm, private "mirror" in Markdown, ` +
      `for their eyes only, with these sections:\n` +
      `## Themes you return to\n## Things that make you proud\n## What you want to improve\n` +
      `## Words you're collecting\n## Your tone lately\n\n` +
      `Be gentle and specific, quoting their own words where possible. Observational, never advice, never diagnosis.\n\n` +
      `ENTRIES:\n${corpus}`;

    const markdown = await callClaude({ system: BLOOM_VOICE, user, model: MODELS.smart, maxTokens: 1200, temperature: 0.7 });
    const period = new Date().toISOString().slice(0, 7); // YYYY-MM
    await supabase.from("ai_outputs").insert({ kind: "mirror", period, content: { markdown }, model: MODELS.smart });

    return json({ period, markdown });
  } catch (err) {
    console.error("mirror error", err);
    return json({ markdown: "", error: "unavailable" }, 200);
  }
});
