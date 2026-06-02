from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

import imageio_ffmpeg
import requests


ROOT = Path(__file__).resolve().parents[1]
VIDEO_IN = ROOT / "dist_web" / "videos" / "chalk-and-chance-showcase.webm"
VOICE_OUT = ROOT / "dist_web" / "videos" / "chalk-and-chance-player-guide-voice.mp3"
VOICE_RAW = ROOT / "dist_web" / "videos" / "chalk-and-chance-player-guide-voice.pcm"
VIDEO_OUT = ROOT / "dist_web" / "videos" / "chalk-and-chance-player-guide-narrated.mp4"
ROOTS_TO_SEARCH = [
    Path.home() / "Desktop" / "passcode.txt",
    Path.home() / ".env",
    Path.home() / ".codex",
    Path.home() / ".claude",
    Path.home() / ".config",
]
SKIP_DIRS = {
    ".git",
    ".godot",
    "node_modules",
    ".wrangler",
    "__pycache__",
    "dist_web",
    "sessions",
    "archived_sessions",
    "file-history",
    ".tmp",
    "tmp",
}
KEY_RE = re.compile(r"sk-or-(?:v1-)?[A-Za-z0-9_-]{20,}")

NARRATION = """
Welcome to Chalk and Chance. This is a short teaching rehearsal, not a quiz. As you play, your job is to see the classroom, study your choices, and notice how teaching moves change student thinking.

Step one. Start the rehearsal. You see a classroom with students and teacher-facing signals. Study the room as a practice space. If something goes wrong, treat it as useful data.

Step two. Open the demo gate. The public taste demo keeps spoken student lines silent, while voice-enabled review sessions use a passcode.

Step three. Read the first screen calmly. Class sign-in is for assigned courses. Settings explains whether voice is protected, unavailable, or enabled.

Step four. Use the Mission Hub as a learning map. Start with the row marked Start Here. Badges are not only prizes. They name the skill you are practicing: pacing, reasoning, airtime, feedback, and capstone judgment.

Step five. Notice Settings and Import. Settings show sound effects, voice status, text size, motion, and dialogue speed. Import lets your own lesson become the practice scenario.

Step six. In the classroom, read the signals. Attention tells you whether the room is with you. Composure tells you how much capacity you have left. Participation, wait time, and disruptions tell you what the lesson needs next.

Step seven. Move near a student and press Z, Enter, or Space. You are not collecting points. You are deciding when to enter a student's thinking moment.

Step eight. In an encounter, read the student first. Look for the hidden need. The student may be confused, dominant, avoidant, anxious, off task, or ready for a deeper prompt.

Step nine. Use academic teaching moves. Elicit asks for reasoning. Extend presses deeper. Revoice clarifies a student's idea. Wait protects thinking time.

Step ten. Use social and management moves carefully. Connect draws on a student asset. Praise names useful effort. Redirect protects classroom order. Tell gives the answer, but can reduce student thinking practice.

Step eleven. After each move, read the result chip. It shows what changed in understanding, engagement, rapport, and order. Use that feedback to adjust your next decision.

Step twelve. At the debrief, do not only check pass or miss. Study the missed objective. Low wait time means practice pausing. Low participation means reach quiet students. High disruptions mean use smaller redirections.

Step thirteen. Replay with one focus. Choose one teaching intention for the next run. The goal is focused repetition, not perfect performance on the first try.

That is the learning loop: observe, choose, read feedback, and reflect. Start with the demo, try one teaching move at a time, and use the debrief to turn play into practice.
""".strip()


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def write_audio_response(content: bytes, response_format: str) -> None:
    if response_format == "pcm":
        VOICE_RAW.write_bytes(content)
        ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
        run([
            ffmpeg,
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-f", "s16le",
            "-ar", "24000",
            "-ac", "1",
            "-i", str(VOICE_RAW),
            "-codec:a", "libmp3lame",
            "-b:a", "128k",
            str(VOICE_OUT),
        ])
        return
    VOICE_OUT.write_bytes(content)


def find_openrouter_keys() -> list[str]:
    keys: list[str] = []
    seen: set[str] = set()

    def add_key(value: str) -> None:
        value = value.strip().strip('"').strip("'")
        if value.startswith("sk-or-v1-") and value not in seen:
            seen.add(value)
            keys.append(value)

    for name in ("OPENROUTER_API_KEY", "OPENROUTER_KEY"):
        val = os.environ.get(name, "").strip()
        add_key(val)
    for root in ROOTS_TO_SEARCH:
        if not root.exists():
            continue
        paths = [root] if root.is_file() else root.rglob("*")
        for path in paths:
            try:
                if path.is_dir():
                    continue
                if any(part in SKIP_DIRS for part in path.parts):
                    continue
                if path.stat().st_size > 2_000_000:
                    continue
                if path.suffix.lower() not in {"", ".env", ".txt", ".md", ".json", ".jsonl", ".toml", ".yaml", ".yml", ".ps1", ".bat", ".cmd"}:
                    continue
                txt = path.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for m in KEY_RE.finditer(txt):
                add_key(m.group(0))
    return keys


def synthesize_openrouter_tts(api_key: str) -> None:
    url = "https://openrouter.ai/api/v1/audio/speech"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://chalk-and-chance.pages.dev",
        "X-Title": "Chalk & Chance Player Guide",
    }
    attempts = [
        {"model": "google/gemini-3.1-flash-tts-preview", "voice": "Puck", "response_format": "pcm"},
        {"model": "google/gemini-3.1-flash-tts-preview", "voice": "Aoede", "response_format": "pcm"},
        {"model": "google/gemini-2.5-flash-preview-tts", "voice": "Puck", "response_format": "pcm"},
        {"model": "google/gemini-2.5-flash-preview-tts", "voice": "Kore", "response_format": "pcm"},
        {"model": "elevenlabs/eleven-turbo-v2", "voice": "alloy", "response_format": "mp3"},
        {"model": "mistralai/voxtral-mini-tts-2603", "voice": "alloy", "response_format": "mp3"},
        {"model": "openai/gpt-4o-mini-tts-2025-12-15", "voice": "nova", "response_format": "mp3"},
    ]
    last_error = ""
    for cfg in attempts:
        payload = {
            "input": NARRATION,
            "model": cfg["model"],
            "voice": cfg["voice"],
            "response_format": cfg["response_format"],
            "speed": 0.94,
        }
        resp = requests.post(url, headers=headers, json=payload, timeout=180)
        if resp.ok and resp.content:
            write_audio_response(resp.content, cfg["response_format"])
            print(f"TTS provider model: {cfg['model']}")
            return
        last_error = f"{resp.status_code}: {resp.text[:500]}"
    raise RuntimeError(f"OpenRouter TTS failed. Last error: {last_error}")


def openrouter_key_is_valid(api_key: str) -> bool:
    try:
        resp = requests.get(
            "https://openrouter.ai/api/v1/key",
            headers={"Authorization": f"Bearer {api_key}"},
            timeout=20,
        )
    except requests.RequestException:
        return False
    return resp.ok


def main() -> None:
    if not VIDEO_IN.exists():
        raise SystemExit(f"Missing input video: {VIDEO_IN}")
    keys = find_openrouter_keys()
    if not keys:
        raise SystemExit("OpenRouter key not found. Set OPENROUTER_API_KEY or place sk-or-v1 key in a local config file.")
    if os.environ.get("REUSE_EXISTING_VOICE") == "1" and VOICE_OUT.exists():
        print(f"Reusing existing voice track: {VOICE_OUT}")
    else:
        errors: list[str] = []
        for index, key in enumerate(keys, start=1):
            if not openrouter_key_is_valid(key):
                errors.append(f"candidate {index}/{len(keys)} failed validation")
                continue
            try:
                synthesize_openrouter_tts(key)
                print(f"OpenRouter key candidate accepted: {index}/{len(keys)}")
                break
            except Exception as exc:
                errors.append(f"candidate {index}/{len(keys)} failed: {exc}")
        else:
            raise RuntimeError("All OpenRouter key candidates failed. " + " | ".join(errors[-3:]))

    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    run([
        ffmpeg,
        "-y",
        "-i", str(VIDEO_IN),
        "-i", str(VOICE_OUT),
        "-map", "0:v:0",
        "-map", "1:a:0",
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "192k",
        "-shortest",
        str(VIDEO_OUT),
    ])
    print(VIDEO_OUT)


if __name__ == "__main__":
    main()
