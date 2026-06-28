// Bloom voice endpoint (Vercel serverless) — "Bloom's voice in the cloud".
// Holds the ElevenLabs key as an encrypted Vercel env var (never in the app or
// git). The app POSTs { text } + an x-bloom-token; we return mp3 audio.
//
// Env vars (set on Vercel, encrypted):
//   ELEVENLABS_API_KEY   (required)
//   BLOOM_TTS_TOKEN      (shared secret the app sends; optional but recommended)
//   ELEVENLABS_VOICE_ID  (optional; default below)
//   ELEVENLABS_MODEL_ID  (optional; default eleven_turbo_v2_5)

const DEFAULT_VOICE = 'EXAVITQu4vr4xnSDxMaL';
const DEFAULT_MODEL = 'eleven_turbo_v2_5';

export default async function handler(req, res) {
  res.setHeader('access-control-allow-origin', '*');
  res.setHeader('access-control-allow-headers', 'content-type, x-bloom-token');
  res.setHeader('access-control-allow-methods', 'POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(404).send('not found');

  const key = process.env.ELEVENLABS_API_KEY;
  if (!key) return res.status(204).end(); // no key → app falls back to on-device voice

  const guard = process.env.BLOOM_TTS_TOKEN || '';
  if (guard && req.headers['x-bloom-token'] !== guard) {
    return res.status(401).send('unauthorized');
  }

  try {
    const body = typeof req.body === 'object' && req.body ? req.body : JSON.parse(req.body || '{}');
    const text = body.text;
    if (!text) return res.status(400).send('text required');

    const voice = process.env.ELEVENLABS_VOICE_ID || DEFAULT_VOICE;
    const model = process.env.ELEVENLABS_MODEL_ID || DEFAULT_MODEL;

    const r = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voice}?output_format=mp3_44100_128`,
      {
        method: 'POST',
        headers: { 'xi-api-key': key, 'content-type': 'application/json' },
        body: JSON.stringify({
          text,
          model_id: model,
          voice_settings: { stability: 0.5, similarity_boost: 0.75, style: 0.3 },
        }),
      },
    );
    if (!r.ok) {
      console.error('elevenlabs', r.status, (await r.text()).slice(0, 300));
      return res.status(502).send('tts failed');
    }
    const buf = Buffer.from(await r.arrayBuffer());
    res.setHeader('content-type', 'audio/mpeg');
    return res.status(200).send(buf);
  } catch (e) {
    console.error('tts error', e);
    return res.status(500).send('error');
  }
}
