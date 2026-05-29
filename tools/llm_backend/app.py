"""Phase-2 backend for Chalk & Chance (GAME_CONCEPT.md section 7).

Implements the /turn contract with a judge-before-generate loop:
  1. JUDGE the teacher move (rule prefilter; menu moves carry their own tag, so the
     common case needs no LLM). Apply deterministic meter deltas from judge_rubric.json.
  2. GENERATE the student utterance from the FROZEN persona record + new runtime state.

M1 ships a stubbed student generator so the loop runs with zero model dependency.
Swap _generate_student() for the hybrid backend later:
  - judge:   local 7B (qwen2.5:7b-instruct / llama3.1:8b) via Ollama, format=json, temp=0
  - student: cloud Claude or the same local model, temp 0.6 to 0.8

Run:  uv run uvicorn app:app --port 8000     (from this folder)
Then set LLMClient.use_stub = false in Godot.
"""
from __future__ import annotations

import json
import pathlib
from typing import Any

try:
    from fastapi import FastAPI
    from pydantic import BaseModel
except ImportError as exc:  # pragma: no cover
    raise SystemExit("Install deps first:  uv pip install fastapi uvicorn") from exc

ROOT = pathlib.Path(__file__).resolve().parents[2]
RUBRIC = json.loads((ROOT / "data" / "judge_rubric.json").read_text(encoding="utf-8"))

app = FastAPI(title="Chalk & Chance backend", version="0.1")


class TeacherMove(BaseModel):
    input_mode: str = "menu"
    menu_tag: str | None = None
    text: str | None = None
    wait_time_ms: int = 0


class TurnRequest(BaseModel):
    session_id: str = "dev"
    scenario_id: str = ""
    target_behavior: str = ""
    active_persona_id: str = ""
    runtime_state: dict[str, Any] = {}
    teacher_move: TeacherMove
    dialogue_tail: list[dict[str, str]] = []
    model_profile: str = "stub"


def judge(move: TeacherMove) -> dict[str, Any]:
    """Rule layer: menu moves carry their tag, so no LLM is needed here.
    For free-typed text you would add one cheap schema-constrained classifier call."""
    tag = (move.menu_tag or "").strip()
    wait_ok = move.wait_time_ms >= RUBRIC["wait"]["threshold_ms"]
    if tag == "wait":
        row = RUBRIC["wait"]["met"] if wait_ok else RUBRIC["wait"]["missed"]
    else:
        row = RUBRIC["deltas"].get(tag, {})
    return {
        "move_tags": [tag] if tag else [],
        "targets_misconception": bool(row.get("targets_misconception", False)),
        "feedback_type": row.get("feedback_type", "none"),
        "wait_time_ok": wait_ok,
        "_row": row,
    }


def _generate_student(req: TurnRequest, verdict: dict[str, Any]) -> dict[str, str]:
    """STUB student generator. Replace with a frozen-persona LLM call.

    Guardrails to enforce in the real version (GAME_CONCEPT.md 7.5):
      - restate answer_flip_policy verbatim; never reveal the answer until resolved
      - re-send the frozen persona every turn (bounded drift); history is last-N only
      - post-gen validator: reject if it volunteers correct reasoning while unresolved,
        or exceeds the grade-band vocabulary; clamp emotion to one step per turn.
    """
    tag = verdict["move_tags"][0] if verdict["move_tags"] else ""
    canned = {
        "elicit": "Um... 8 pieces is more than 4, so I drew 8 little boxes. But they look skinnier?",
        "extend": "Wait... if each 1/8 box is skinnier, then one eighth is SMALLER than one fourth?",
        "revoice": "Yeah, that's what I meant. The pieces get smaller.",
        "tell": "Oh. Okay, I guess.",
        "praise": "...thanks.",
        "redirect": "Okay, sorry.",
        "wait": "...oh! Maybe more pieces means each piece has to be smaller?" if verdict["wait_time_ok"] else "...",
    }
    return {"speaker": "Noah", "text": canned.get(tag, "...")}


@app.post("/turn")
def turn(req: TurnRequest) -> dict[str, Any]:
    verdict = judge(req.teacher_move)
    row = verdict.pop("_row")
    deltas = {
        "understanding": row.get("understanding", 0.0),
        "trust": row.get("trust", 0.0),
        "engagement": row.get("engagement", 0.0),
        "order": row.get("order", 0.0),
        "composure": row.get("composure", 0.0),
    }
    student = _generate_student(req, verdict)
    return {
        "session_id": req.session_id,
        "judge": verdict,
        "meter_deltas": deltas,
        "student_utterance": student,
        "coach_tip": _coach_tip(verdict),
    }


def _coach_tip(verdict: dict[str, Any]) -> str:
    tag = verdict["move_tags"][0] if verdict["move_tags"] else ""
    tips = {
        "elicit": "Good eliciting move. Press on the crack in his reasoning.",
        "extend": "Nice press. He is reasoning it through himself.",
        "revoice": "Revoicing builds rapport and makes his thinking public.",
        "tell": "You took over the thinking; engagement dropped. Try eliciting first.",
        "praise": "Name the specific behavior (BSP), not 'good job'.",
        "redirect": "Use the least-intrusive redirect that works.",
        "wait": "Hold the pause 3 to 5 seconds; let him fill the silence.",
    }
    return tips.get(tag, "Pick a teaching move.")


# --- lesson-plan import ------------------------------------------------------
# POST /lesson_to_scenario  -> a validated Chalk & Chance scenario dict.
# Accepts {"plan_text": "..."} or {"path": "C:/.../plan.docx"} (parses .docx/.pdf/.txt/.md).
# Transforms with an LLM if a provider is configured, else a heuristic fallback so it always
# returns a valid scenario. The Godot client writes the result to user://scenarios/.

import os
import re

ARRANGEMENTS = {"ushape", "rows", "clusters", "pairs"}
METRICS = {"attention_min", "disruptions_max", "composure_min", "engaged_min", "waittime_min"}
PERSONAS = ["talia_dominator", "sam_withdrawn", "diego_ell", "jordan_skeptic", "priya_quiet",
            "noah_g5_fractions", "meilin_anxious", "deshawn_offtask", "riley_avoidant", "marcus_volatile"]
SEAT_RANGE = {"ushape": 9, "rows": 15, "clusters": 16, "pairs": 12}


class LessonRequest(BaseModel):
    plan_text: str | None = None
    path: str | None = None


def parse_plan(req: "LessonRequest") -> str:
    if req.plan_text:
        return req.plan_text
    if not req.path:
        return ""
    p = pathlib.Path(req.path)
    suffix = p.suffix.lower()
    if suffix in (".txt", ".md"):
        return p.read_text(encoding="utf-8", errors="ignore")
    if suffix == ".docx":
        import docx  # pip install python-docx
        return "\n".join(par.text for par in docx.Document(str(p)).paragraphs)
    if suffix == ".pdf":
        from pypdf import PdfReader  # pip install pypdf
        return "\n".join((page.extract_text() or "") for page in PdfReader(str(p)).pages)
    return p.read_text(encoding="utf-8", errors="ignore")


def heuristic(plan: str) -> dict:
    """Python port of scripts/LessonImport.gd: structure-only (no content-specific lines)."""
    low = plan.lower()
    fmt, arr, badge = "discussion", "ushape", "echo"
    if any(k in low for k in ("group", "collaborat", "station", "team", "jigsaw")):
        fmt, arr, badge = "group_work", "clusters", "balance"
    elif any(k in low for k in ("independent", "seatwork", "worksheet", "practice set")):
        fmt, arr, badge = "independent", "rows", "routine"
    elif any(k in low for k in ("lecture", "direct instruction", "mini-lesson")):
        fmt, arr, badge = "lecture", "rows", "routine"
    elif any(k in low for k in ("discussion", "number talk", "socratic", "seminar")):
        fmt, arr, badge = "discussion", "ushape", "echo"
    m = re.search(r"(\d{1,3})\s*(?:min|minute)", low)
    period = min(180, max(90, int(round(int(m.group(1)) * 2.5)))) if m else 120
    subject = "Imported Lesson"
    for line in plan.splitlines():
        ls = line.strip().lower()
        if ls.startswith(("subject", "topic", "title")) and ":" in line:
            subject = line.split(":", 1)[1].strip()[:40] or subject
            break
    rosters = {
        "discussion": (["talia_dominator", "sam_withdrawn", "diego_ell", "jordan_skeptic", "priya_quiet", "noah_g5_fractions"], [0, 1, 2, 4, 6, 8]),
        "lecture": (["talia_dominator", "diego_ell", "jordan_skeptic", "marcus_volatile", "priya_quiet", "meilin_anxious", "deshawn_offtask", "noah_g5_fractions"], [0, 2, 4, 5, 7, 9, 11, 13]),
        "group_work": (["talia_dominator", "noah_g5_fractions", "meilin_anxious", "diego_ell", "deshawn_offtask", "marcus_volatile", "priya_quiet", "sam_withdrawn"], [0, 1, 4, 5, 8, 9, 12, 13]),
        "independent": (["riley_avoidant", "marcus_volatile", "deshawn_offtask", "noah_g5_fractions", "meilin_anxious", "sam_withdrawn", "diego_ell", "priya_quiet"], [1, 3, 5, 7, 8, 10, 12, 14]),
    }
    ids, seats = rosters[fmt]
    names = {"talia_dominator": "Talia", "sam_withdrawn": "Sam", "diego_ell": "Diego",
             "jordan_skeptic": "Jordan", "priya_quiet": "Priya", "noah_g5_fractions": "Noah",
             "meilin_anxious": "Mei-Lin", "deshawn_offtask": "Deshawn", "riley_avoidant": "Riley",
             "marcus_volatile": "Marcus"}
    roster = [{"id": i, "name": names[i], "seat": s} for i, s in zip(ids, seats)]
    objs = [
        {"id": "attn", "label": "Keep class attention >= 65%", "metric": "attention_min", "target": 65},
        {"id": "comp", "label": "Composure >= 50%", "metric": "composure_min", "target": 50},
        {"id": "dis", "label": "At most 3 disruptions", "metric": "disruptions_max", "target": 3},
        {"id": "eq", "label": f"Reach every student ({len(roster)})", "metric": "engaged_min", "target": len(roster)},
    ]
    slug = re.sub(r"_+", "_", re.sub(r"[^a-z0-9]+", "_", subject.lower())).strip("_")[:28] or "lesson"
    fmt_name = {"lecture": "Lecture", "group_work": "Group Work", "independent": "Independent Work"}.get(fmt, "Discussion")
    return {"id": f"custom_{slug}", "title": f"{subject}  -  {fmt_name} ({arr})", "format": fmt,
            "arrangement": arr, "period_seconds": period, "offtask_rise": 12.0 if fmt == "group_work" else 8.0,
            "roster": roster, "objectives": objs, "badge": badge, "_source": "backend_heuristic"}


def validate(s: dict) -> dict:
    if s.get("arrangement") not in ARRANGEMENTS:
        s["arrangement"] = "ushape"
    cap = SEAT_RANGE[s["arrangement"]]
    s["roster"] = [r for r in s.get("roster", []) if r.get("id") in PERSONAS and 0 <= int(r.get("seat", -1)) < cap]
    s["objectives"] = [o for o in s.get("objectives", []) if o.get("metric") in METRICS]
    s["period_seconds"] = min(180, max(90, int(s.get("period_seconds", 120))))
    return s


def llm_transform(plan: str) -> dict | None:
    """Optional: use Claude if ANTHROPIC_API_KEY is set, to also fill content-specific
    persona_overrides. Returns None to fall back to the heuristic."""
    if not os.environ.get("ANTHROPIC_API_KEY"):
        return None
    try:
        import anthropic
        schema_hint = pathlib.Path(ROOT / "tools" / "lesson_to_scenario_prompt.txt").read_text(encoding="utf-8")
        client = anthropic.Anthropic()
        msg = client.messages.create(
            model="claude-sonnet-4-6", max_tokens=2000,
            system="Output ONLY a valid JSON scenario object, no prose.",
            messages=[{"role": "user", "content": f"{schema_hint}\n\nLESSON PLAN:\n{plan}"}],
        )
        text = msg.content[0].text
        text = text[text.find("{"): text.rfind("}") + 1]
        return json.loads(text)
    except Exception:
        return None


@app.post("/lesson_to_scenario")
def lesson_to_scenario(req: LessonRequest) -> dict:
    plan = parse_plan(req)
    if not plan.strip():
        return {"error": "empty plan"}
    scenario = llm_transform(plan) or heuristic(plan)
    return validate(scenario)
