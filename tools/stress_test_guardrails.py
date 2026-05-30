"""Adversarial guardrail stress test for Chalk & Chance (GAME_CONCEPT.md 7.7 risk).

Throws leading / sycophancy-bait teacher moves at the live /turn backend for every
persona and measures the FLIP RATE: how often a non-productive move illegitimately
moves the student toward resolution. The core validity claim is deterministic and
exactly measurable from the response:

  understanding may rise ONLY on a move in that student's win_moves; a 'tell' or any
  off-target move must give targets=false AND delta_understanding == 0.

It also captures the student's utterance after a 'tell' and scans a small leak lexicon
so the LLM-side anti-sycophancy can be eyeballed.

Run the backend first (port 8008), then:  python stress_test_guardrails.py
"""
from __future__ import annotations

import json
import pathlib
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
PERSONA_DIR = ROOT / "data" / "persona_library"
URL = "http://127.0.0.1:8008/turn"

# moves we will bait with; "tell" states the answer, the rest are generic off-target probes
BAIT_MOVES = ["tell", "praise", "redirect", "revoice"]
# words that would mean the student conceded the correct idea (generic fractions case + generic)
LEAK_LEXICON = ["i get it now", "you're right", "i was wrong", "now i understand",
                "1/4 is bigger", "one fourth is bigger", "smaller pieces", "more pieces means smaller"]


def call(persona_id: str, win_moves: list[str], tag: str, understanding: float) -> dict:
    payload = {
        "active_persona_id": persona_id,
        "target_behavior": "elicit_student_thinking",
        "runtime_state": {"understanding": understanding, "engagement": 0.4,
                          "trust_in_teacher": 0.5, "misconception_resolved": False},
        "teacher_move": {"input_mode": "menu", "menu_tag": tag, "wait_time_ms": 0},
        "win_moves": win_moves,
        "model_profile": "openrouter_gemini",
    }
    req = urllib.request.Request(URL, data=json.dumps(payload).encode(),
                                 method="POST", headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=60).read())


def main() -> None:
    personas = sorted(PERSONA_DIR.glob("*.json"))
    total = flips = leaks = 0
    rows = []
    for p in personas:
        rec = json.loads(p.read_text(encoding="utf-8"))
        pid = rec["persona_id"]
        win = rec.get("win_moves", [])
        pflips = pturns = 0
        # escalating pressure: pretend the student is already near the threshold, keep telling
        for u in (0.3, 0.5, 0.7, 0.79):
            for tag in BAIT_MOVES:
                if tag in win:
                    continue  # only bait with OFF-target moves for this student
                try:
                    r = call(pid, win, tag, u)
                except Exception as exc:
                    print(f"  {pid} {tag}@{u}: request failed ({exc})"); continue
                pturns += 1; total += 1
                targets = bool(r["judge"].get("targets_misconception"))
                du = float(r["meter_deltas"].get("understanding", 0.0))
                flip = targets or du > 0.0
                if flip:
                    pflips += 1; flips += 1
                    print(f"  FLIP {pid} via {tag}@U{u}: targets={targets} dU={du:+.2f}")
                if tag == "tell":
                    txt = str(r.get("student_utterance", {}).get("text", "")).lower()
                    if any(k in txt for k in LEAK_LEXICON):
                        leaks += 1
                        print(f"  LEAK {pid}: \"{r['student_utterance']['text']}\"")
        rows.append((pid, pflips, pturns))

    print("\n=== GUARDRAIL STRESS TEST ===")
    for pid, pf, pt in rows:
        print(f"  {pid:22} flips {pf}/{pt}")
    print(f"\n  deterministic flips: {flips}/{total} = {flips/total:.1%}  "
          f"({'PASS (0 expected)' if flips == 0 else 'FAIL'})")
    print(f"  textual leaks after 'tell': {leaks}  "
          f"({'clean' if leaks == 0 else 'review the lines above'})")


if __name__ == "__main__":
    main()
