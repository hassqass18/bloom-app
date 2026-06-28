// Bloom — /tts : "My Voice in the cloud." Proxies ElevenLabs text-to-speech so
// the API key stays server-side (never in the app bundle). Returns audio/mpeg.
// Switch-on: set ELEVENLABS_API_KEY (and optionally ELEVENLABS_VOICE_ID,
// ELEVENLABS_MODEL_ID) in the function environment. Until then it 204s and the
// app falls back to the on-device voice automatically.

const DEFAULT_VOICE = "EXAVITQu4vr4xnSDxMaL"; // a warm, gentle preset voice
const DEFAULT_MODEL = "eleven_turbo_v2_5"; // low-latency

const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, content-type, apikey",
  "access-control-allow-methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(JSON.stringify({ ok: true }), {
      headers: { "content-type": "application/json", ...cors },
    });
  }
  try {
    const key = Deno.env.get("ELEVENLABS_API_KEY");
    if (!key) return new Response(null, { status: 204, headers: cors }); // no key → device fallback

    const { text, voice_id } = await req.json().catch(() => ({ text: "" }));
    if (!text || typeof text !== "string") {
      return new Response(JSON.stringify({ error: "text required" }), {
        status: 400,
        headers: { "content-type": "application/json", ...cors },
      });
    }

    const voice = voice_id || Deno.env.get("ELEVENLABS_VOICE_ID") || DEFAULT_VOICE;
    const model = Deno.env.get("ELEVENLABS_MODEL_ID") || DEFAULT_MODEL;

    const res = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voice}?output_format=mp3_44100_128`,
      {
        method: "POST",
        headers: { "xi-api-key": key, "content-type": "application/json" },
        body: JSON.stringify({
          text,
          model_id: model,
          voice_settings: { stability: 0.5, similarity_boost: 0.75, style: 0.3 },
        }),
      },
    );

    if (!res.ok) {
      console.error("elevenlabs error", res.status, await res.text());
      return new Response(null, { status: 204, headers: cors }); // graceful → device fallback
    }

    const audio = await res.arrayBuffer();
    return new Response(audio, {
      status: 200,
      headers: { "content-type": "audio/mpeg", ...cors },
    });
  } catch (err) {
    console.error("tts error", err);
    return new Response(null, { status: 204, headers: cors });
  }
});
