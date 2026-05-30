"""ECD measurement model for Chalk & Chance: estimate the PLAYER-teacher's competency
vector from the telemetry evidence stream with a multivariate Elo.

Pipeline (Evidence-Centered Design):
  telemetry JSONL  ->  evidence rules (data/competency_model.json)  ->  observations
  (student=player, item=move::persona, y in {0,1})  ->  MultivariateElo.update stream
  ->  theta (per-competency ability) + uncertainty (Pelanek a/(1+b*n)).

Reuses the validated engine from the P1 line: ogd-p1-elo/src/elo.py
(Ruiperez-Valiente, Kim, Baker, Martinez & Lin 2023, IEEE TLT).

Usage:
  python fit_competencies.py [path/to/session.jsonl]   # default: newest in Godot user dir
"""
from __future__ import annotations

import glob
import json
import math
import os
import sys
import pathlib
from collections import Counter

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[1]
ELO_SRC = pathlib.Path.home() / "Projects" / "ogd-p1-elo" / "src"
sys.path.insert(0, str(ELO_SRC))
from elo import MultivariateElo  # noqa: E402

MODEL = json.loads((ROOT / "data" / "competency_model.json").read_text(encoding="utf-8"))
SKILLS = [s["id"] for s in MODEL["skills"]]
SKILL_IX = {s: i for i, s in enumerate(SKILLS)}
RULES = {k: v for k, v in MODEL["evidence_rules"].items() if not k.startswith("_")}
USER_DIR = os.path.expanduser(r"~\AppData\Roaming\Godot\app_userdata\Chalk & Chance\telemetry")


def newest() -> str | None:
    fs = glob.glob(os.path.join(USER_DIR, "*.jsonl"))
    return max(fs, key=os.path.getmtime) if fs else None


def success(turn: dict, y_from: str) -> int:
    j = turn.get("judge", {})
    d = turn.get("deltas", {})
    if y_from == "targets":
        return int(bool(j.get("targets")))
    if y_from == "wait_ok":
        return int(bool(j.get("wait_ok")))
    if y_from == "order_up":
        return int(float(d.get("order", 0)) > 0)
    if y_from == "trust_up":
        return int(float(d.get("trust", 0)) > 0)
    if y_from == "const1":
        return 1
    if y_from == "const0":
        return 0
    return 0


def main() -> None:
    path = sys.argv[1] if len(sys.argv) > 1 else newest()
    if not path or not os.path.isfile(path):
        print("no telemetry; play/smoke a session first"); return
    turns = [json.loads(l) for l in open(path, encoding="utf-8") if l.strip()]
    turns = [t for t in turns if t.get("event") == "turn"]
    turns.sort(key=lambda t: t.get("t_ms", 0))
    if not turns:
        print("no turn events"); return

    # Build observations + the item set (item = move-tag :: persona, task-model granularity).
    obs = []  # (item_id, skill_ids, y)
    for t in turns:
        tag = str(t.get("move", {}).get("tag", ""))
        rule = RULES.get(tag)
        if not rule:
            continue
        item = f"{tag}::{t.get('persona_id', '?')}"
        sk = [SKILL_IX[s] for s in rule["skills"] if s in SKILL_IX]
        if not sk:
            continue
        obs.append((item, sk, success(t, rule["y_from"])))

    if not obs:
        print("no scorable observations"); return

    item_ids = sorted({o[0] for o in obs})
    item_ix = {iid: i for i, iid in enumerate(item_ids)}
    K = len(SKILLS)
    q = np.zeros((len(item_ids), K))
    for iid in item_ids:
        tag = iid.split("::", 1)[0]
        for s in RULES[tag]["skills"]:
            q[item_ix[iid], SKILL_IX[s]] = 1.0

    p = MODEL.get("elo_params", {})
    elo = MultivariateElo(n_skills=K, item_ids=item_ids, q_matrix=q,
                          a=float(p.get("a", 1.0)), b=float(p.get("b", 0.05)))

    PLAYER = "teacher"
    preds, ys = [], []
    for item, _sk, y in obs:
        preds.append(elo.update(PLAYER, item, y))
        ys.append(y)

    theta = elo.theta[PLAYER]
    n_theta = elo.n_theta[PLAYER]

    # prequential fit (Brier + accuracy of pre-update predictions)
    preds = np.array(preds); ys = np.array(ys)
    brier = float(np.mean((preds - ys) ** 2))
    acc = float(np.mean((preds >= 0.5).astype(int) == ys))

    print(f"session: {os.path.basename(path)}   scorable moves: {len(obs)}")
    print(f"prequential Brier={brier:.3f}  acc={acc:.0%}\n")
    print("TEACHER COMPETENCY ESTIMATES (multivariate Elo theta)")
    print(f"  {'competency':28} {'theta':>7} {'logodds->P':>10} {'n':>4} {'uncertainty':>11}")
    for i, sid in enumerate(SKILLS):
        n = float(n_theta[i])
        unc = p.get("a", 1.0) / (1.0 + p.get("b", 0.05) * n)   # Pelanek step-size as uncertainty proxy
        prob = 1.0 / (1.0 + math.exp(-max(-32, min(32, theta[i]))))
        bar = "#" * int(round(prob * 20))
        flag = "  (no evidence yet)" if n == 0 else ""
        print(f"  {sid:28} {theta[i]:+7.2f} {prob:>9.0%} {int(n):>4} {unc:>11.2f}  {bar}{flag}")

    # learned per-(move::persona) task difficulty (calibration view): higher beta = harder
    print("\nTASK DIFFICULTY (learned beta per move::persona; higher = harder to succeed)")
    diff = []
    for iid in item_ids:
        i = item_ix[iid]
        bsum = float(elo.beta[i].sum())   # single-skill items: one nonzero entry
        diff.append((iid, bsum, int(elo.n_beta[i].sum())))
    for iid, b, nb in sorted(diff, key=lambda x: -x[1])[:8]:
        print(f"  {iid:34} beta={b:+.2f}  n={nb}")

    # session-level: equity competency
    per_student = Counter(t.get("persona_id") for t in turns)
    if per_student:
        top = max(per_student.values()) / sum(per_student.values())
        print(f"\nSESSION COMPETENCY")
        print(f"  equitable_participation  score={1 - top:.2f}  (top-student share {top:.0%}, "
              f"{'OK' if top <= 0.6 else 'inequitable'})")
    print("\nNote: theta is on the logit scale (0 = baseline). Positive = above the difficulty "
          "of the moves attempted; uncertainty shrinks as evidence (n) accumulates per skill.")


if __name__ == "__main__":
    main()
