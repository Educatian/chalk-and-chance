// /tts ported from app.py so the WEB game speaks student lines (ElevenLabs per-persona
// child voices). ELEVENLABS_API_KEY is a Worker secret. Returns raw mp3 bytes, or 204 when
// no audio is available so the game stays silent and never errors.
import { VOICE_PROFILES } from "./gamedata.js";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Voice-Gate",
};

// emotion_shown -> [stability, style]; lower stability + higher style = more expressive
const EMO = {
  neutral: [0.5, 0.3], thinking: [0.5, 0.3], curious: [0.42, 0.45], engaged: [0.4, 0.5],
  excited: [0.3, 0.65], proud: [0.38, 0.55], warming: [0.45, 0.45], shy: [0.55, 0.3],
  confused: [0.45, 0.4], anxious: [0.38, 0.45], frustrated: [0.33, 0.55], withdrawn: [0.58, 0.25],
  guarded: [0.58, 0.25], nervous: [0.38, 0.45], defiant: [0.33, 0.55],
};

export async function handleTts(req, env) {
  const gate = (env.TTS_GATE_CODE || "MAPLE-RIDGE").trim();
  if (gate && (req.headers.get("X-Voice-Gate") || "").trim() !== gate) {
    return new Response(null, { status: 204, headers: CORS });
  }
  const { persona_id, text, emotion, model_id } = await req.json();
  const key = (env.ELEVENLABS_API_KEY || "").trim();
  const vid = VOICE_PROFILES[persona_id];
  if (!key || !vid || !(text || "").trim()) {
    return new Response(null, { status: 204, headers: CORS });
  }
  const [stability, style] = EMO[(emotion || "neutral").toLowerCase()] || [0.5, 0.35];
  const r = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${vid}?output_format=mp3_44100_128`,
    {
      method: "POST",
      headers: { "xi-api-key": key, "Content-Type": "application/json", Accept: "audio/mpeg" },
      body: JSON.stringify({
        text, model_id: model_id || "eleven_multilingual_v2",
        voice_settings: { stability, similarity_boost: 0.75, style, use_speaker_boost: true },
      }),
    });
  if (!r.ok) return new Response(null, { status: 204, headers: CORS });
  return new Response(r.body, { status: 200, headers: { "Content-Type": "audio/mpeg", ...CORS } });
}
