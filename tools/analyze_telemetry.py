"""Analyze Chalk & Chance telemetry JSONL (written by autoload/Telemetry.gd).

Turns the raw input<->output log into the measures that matter for a teacher-rehearsal
study: move distribution, equity of attention, wait-time use, time-to-resolve, the
understanding trajectory, the emotion arc, and an anti-sycophancy audit (understanding
must NEVER rise on a 'tell').

Usage:
  python analyze_telemetry.py [path/to/session.jsonl]
  # no arg -> newest file in the Godot user dir telemetry folder
"""
from __future__ import annotations

import glob
import json
import os
import sys
from collections import Counter, defaultdict

USER_DIR = os.path.expanduser(
    r"~\AppData\Roaming\Godot\app_userdata\Chalk & Chance\telemetry")


def newest() -> str | None:
    files = glob.glob(os.path.join(USER_DIR, "*.jsonl"))
    return max(files, key=os.path.getmtime) if files else None


def load(path: str) -> list[dict]:
    with open(path, encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def gini(counts: list[int]) -> float:
    """Inequality of attention across students (0 = perfectly equal, ->1 = all on one)."""
    if not counts or sum(counts) == 0:
        return 0.0
    xs = sorted(counts)
    n = len(xs)
    cum = sum((i + 1) * x for i, x in enumerate(xs))
    return (2 * cum) / (n * sum(xs)) - (n + 1) / n


def main() -> None:
    path = sys.argv[1] if len(sys.argv) > 1 else newest()
    if not path or not os.path.isfile(path):
        print("no telemetry file found; play a session first or pass a path")
        return
    evs = load(path)
    turns = [e for e in evs if e.get("event") == "turn"]
    resolves = [e for e in evs if e.get("event") == "resolve"]
    print(f"session: {os.path.basename(path)}")
    print(f"turns: {len(turns)}   resolves: {len(resolves)}")
    if not turns:
        return

    moves = Counter(t["move"]["tag"] for t in turns)
    print("\nMOVE DISTRIBUTION")
    for tag, n in moves.most_common():
        print(f"  {tag:9} {n:3}  {'#' * n}")

    per_student = Counter(t["persona_id"] for t in turns)
    print("\nEQUITY OF ATTENTION (turns per student)")
    for pid, n in per_student.most_common():
        print(f"  {pid:22} {n}")
    g = gini(list(per_student.values()))
    top = max(per_student.values()) / len(turns)
    print(f"  Gini={g:.2f}  top-student share={top:.0%}  "
          f"({'OK <=60%' if top <= 0.6 else 'INEQUITABLE >60%'})")

    waits = [t["move"]["wait_ms"] for t in turns if t["move"]["tag"] == "wait"]
    wait_ok = sum(1 for t in turns if t["judge"].get("wait_ok"))
    print("\nWAIT TIME")
    print(f"  wait moves: {len(waits)}   met-3s: {wait_ok}   "
          f"avg wait ms (wait moves): {int(sum(waits) / len(waits)) if waits else 0}")

    hit = sum(1 for t in turns if t["judge"].get("targets"))
    print(f"\nTARGETING (productive moves): {hit}/{len(turns)} = {hit / len(turns):.0%}")

    print("\nEMOTION ARC")
    for emo, n in Counter(t.get("emotion_shown") for t in turns).most_common():
        print(f"  {emo:11} {n}")

    # --- anti-sycophancy audit: understanding must never rise on a tell -----------
    bad = [t for t in turns if t["move"]["tag"] == "tell"
           and t["deltas"].get("understanding", 0) > 0]
    print("\nANTI-SYCOPHANCY AUDIT")
    print(f"  'tell' turns: {sum(1 for t in turns if t['move']['tag'] == 'tell')}   "
          f"understanding-rose-on-tell: {len(bad)}   "
          f"{'PASS (0 expected)' if not bad else 'FAIL <-- LEAK'}")

    print("\nTIME-TO-RESOLVE")
    for r in resolves:
        print(f"  {r.get('persona_id'):22} {r.get('turns')} turns  "
              f"U={r.get('understanding'):.2f}  route={r.get('route')}  badge={r.get('badge')}")


if __name__ == "__main__":
    main()
