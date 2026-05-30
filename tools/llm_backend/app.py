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
import os
import pathlib
import re
from typing import Any

try:
    from fastapi import FastAPI
    from pydantic import BaseModel
except ImportError as exc:  # pragma: no cover
    raise SystemExit("Install deps first:  uv pip install fastapi uvicorn") from exc

ROOT = pathlib.Path(__file__).resolve().parents[2]
RUBRIC = json.loads((ROOT / "data" / "judge_rubric.json").read_text(encoding="utf-8"))

app = FastAPI(title="Chalk & Chance backend", version="0.1")

try:
    from fastapi.middleware.cors import CORSMiddleware
    app.add_middleware(
        CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"],
    )
except Exception:  # pragma: no cover
    pass


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
    move_history: list[dict[str, Any]] = []  # recent [{tag, targets}] for adaptive/fading coach
    win_moves: list[str] = []          # moves that actually unlock THIS student (differentiated)
    frozen_persona: dict[str, Any] = {}  # optional; backend loads from disk if absent
    model_profile: str = "stub"


def judge(move: TeacherMove, win_moves: list[str]) -> dict[str, Any]:
    """Rule layer: menu moves carry their tag, so no LLM is needed here.
    For free-typed text you would add one cheap schema-constrained classifier call.

    Differentiated gate (parity with the Godot stub): a move only counts as
    targets_misconception (and only then can understanding rise) if it is in THIS
    student's win_moves. So elicit unlocks Noah but not a student who needs de-escalation."""
    tag = (move.menu_tag or "").strip()
    wait_ok = move.wait_time_ms >= RUBRIC["wait"]["threshold_ms"]
    if tag == "wait":
        row = dict(RUBRIC["wait"]["met"] if wait_ok else RUBRIC["wait"]["missed"])
    else:
        row = dict(RUBRIC["deltas"].get(tag, {}))

    targets = bool(row.get("targets_misconception", False))
    if win_moves and tag and tag not in win_moves:
        # not the move that unlocks THIS student: no understanding gain, not a resolving move
        targets = False
        row["understanding"] = 0.0
    row["targets_misconception"] = targets
    return {
        "move_tags": [tag] if tag else [],
        "targets_misconception": targets,
        "feedback_type": row.get("feedback_type", "none"),
        "wait_time_ok": wait_ok,
        "_row": row,
    }


def _canned_student(req: TurnRequest, verdict: dict[str, Any]) -> dict[str, str]:
    """Deterministic fallback student generator (used when no LLM is configured or
    the OpenRouter call / validator fails). Keeps the game running with zero deps."""
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


# --- free-text move classifier (GAME_CONCEPT 7.4 LLM classifier layer) -------
# Menu moves carry their tag (no LLM). For a TYPED teacher utterance we classify it
# into exactly one move tag, then the SAME deterministic judge/rubric applies.

CLASSIFIER_MODEL = os.environ.get("OPENROUTER_CLASSIFIER_MODEL", "google/gemini-2.5-flash-lite")
_MOVE_TAGS = ["elicit", "extend", "revoice", "tell", "praise", "redirect", "wait", "connect"]
_CLASSIFY_SYS = (
    "You label a teacher's utterance to a student with EXACTLY ONE move tag.\n"
    "elicit = asks the student to explain HOW/WHY they think (surfaces reasoning).\n"
    "extend = pushes the student's own idea further with a follow-up.\n"
    "revoice = restates/affirms the student's thinking back to them.\n"
    "tell = states the answer or explains the concept directly (takes over).\n"
    "praise = praises the student.\n"
    "redirect = manages behavior / refocuses attention.\n"
    "wait = silence / giving think time (no real content).\n"
    "connect = asks about the student's life/interests/strengths outside the task.\n"
    'Return ONLY JSON: {"tag":"<one tag>"}.'
)


def _heuristic_classify(text: str) -> str:
    t = text.lower().strip()
    if not t:
        return "wait"
    if any(k in t for k in ("how did you", "why do you", "can you show me", "what makes you", "how do you")):
        return "elicit"
    if "?" in t and any(k in t for k in ("what if", "what about", "and then", "so what", "what else")):
        return "extend"
    if t.startswith(("so you", "so what you", "you're saying", "what i hear")):
        return "revoice"
    if any(k in t for k in ("good job", "nice work", "i like how", "well done", "great")):
        return "praise"
    if any(k in t for k in ("settle", "focus", "quiet", "back to", "stop", "eyes up")):
        return "redirect"
    if any(k in t for k in ("tell you about", "what do you like", "outside class", "good at")):
        return "connect"
    if any(k in t for k in ("the answer is", "actually it", "here's how", "let me show", "because the")):
        return "tell"
    return "elicit"


def classify_move(text: str) -> str:
    key = _openrouter_key()
    if not key:
        return _heuristic_classify(text)
    try:
        msgs = [{"role": "system", "content": _CLASSIFY_SYS},
                {"role": "user", "content": text[:500]}]
        body = json.dumps({"model": CLASSIFIER_MODEL, "messages": msgs, "temperature": 0.0,
                           "max_tokens": 20, "response_format": {"type": "json_object"}}).encode()
        rq = urllib.request.Request(OPENROUTER_URL, data=body, method="POST", headers={
            "Authorization": f"Bearer {key}", "Content-Type": "application/json"})
        raw = json.loads(urllib.request.urlopen(rq, timeout=12).read())["choices"][0]["message"]["content"]
        tag = str(json.loads(raw[raw.find("{"): raw.rfind("}") + 1]).get("tag", "")).strip().lower()
        return tag if tag in _MOVE_TAGS else _heuristic_classify(text)
    except Exception as exc:
        print(f"[classify] fallback ({exc})")
        return _heuristic_classify(text)


# --- OpenRouter (Gemini) student generator -----------------------------------
# Frozen-persona, anti-sycophancy student utterance. Dev path; key never ships to
# the client. Set OPENROUTER_API_KEY (or drop the key in OPENROUTER_API_KEY_FILE).

import urllib.request
import urllib.error

PERSONA_DIR = ROOT / "data" / "persona_library"
PROMPT_TEMPLATE = (ROOT / "tools" / "student_prompt.txt").read_text(encoding="utf-8")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
STUDENT_MODEL = os.environ.get("OPENROUTER_STUDENT_MODEL", "google/gemini-2.5-flash-lite")


def _openrouter_key() -> str | None:
    key = os.environ.get("OPENROUTER_API_KEY", "").strip()
    if key:
        return key
    # dev convenience: read a key file if pointed at one
    path = os.environ.get("OPENROUTER_API_KEY_FILE", "").strip()
    if path and pathlib.Path(path).is_file():
        return pathlib.Path(path).read_text(encoding="utf-8").strip()
    return None


def _load_persona(req: TurnRequest) -> dict[str, Any]:
    if req.frozen_persona:
        return req.frozen_persona
    p = PERSONA_DIR / f"{req.active_persona_id}.json"
    if p.is_file():
        return json.loads(p.read_text(encoding="utf-8"))
    return {}


def _build_messages(req: TurnRequest, persona: dict[str, Any], verdict: dict[str, Any]) -> list[dict[str, str]]:
    ks = persona.get("knowledge_state", {})
    bt = persona.get("behavior_tendencies", {})
    rs = req.runtime_state
    tag = verdict["move_tags"][0] if verdict["move_tags"] else ""
    tail = "\n".join(f'{d.get("speaker","?")}: {d.get("text","")}' for d in req.dialogue_tail[-6:]) or "(start of conversation)"

    def lst(v: Any) -> str:
        return "; ".join(v) if isinstance(v, list) else str(v)

    sys = PROMPT_TEMPLATE
    repl = {
        "[[PERSONA_JSON]]": json.dumps({k: persona.get(k) for k in (
            "display_name", "grade_band", "subject_context", "traits", "behavior_tendencies")}, ensure_ascii=False, indent=2),
        "[[FROZEN_MISCONCEPTION]]": str(ks.get("frozen_misconception", "")),
        "[[FACTS_KNOWN]]": lst(ks.get("correct_facts_known", [])),
        "[[FACTS_NOT_KNOWN]]": lst(ks.get("facts_NOT_known", [])),
        "[[WILL_NOT_INVENT]]": str(ks.get("will_not_invent_beyond", "the lesson's grade level")),
        "[[GRADE_BAND]]": str(persona.get("grade_band", "grade-level")),
        "[[RESPONSE_LENGTH]]": str(bt.get("default_response_length", "1-2 sentences")),
        "[[FLIP_POLICY]]": str(persona.get("answer_flip_policy", "Keep your stated understanding unless you reason it out yourself.")),
        "[[RESOLVED]]": "true" if rs.get("misconception_resolved", False) else "false",
        "[[EMOTION_BASELINE]]": str(persona.get("emotion_baseline", "neutral")),
        "[[CURRENT_EMOTION]]": str(rs.get("emotion", persona.get("emotion_baseline", "neutral"))),
        "[[ESCALATION]]": lst(persona.get("escalation_triggers", [])),
        "[[DEESCALATION]]": lst(persona.get("deescalation_moves", [])),
        "[[HIDDEN_NEED]]": str(persona.get("hidden_need", "")),
        "[[UNDERSTANDING]]": str(round(float(rs.get("understanding", 0.15)), 2)),
        "[[TRUST]]": str(round(float(rs.get("trust_in_teacher", 0.5)), 2)),
        "[[ENGAGEMENT]]": str(round(float(rs.get("engagement", 0.4)), 2)),
        "[[MOVE_TAG]]": tag or "(said something)",
        "[[TARGETS]]": "IS" if verdict.get("targets_misconception") else "is NOT",
        "[[WAIT_OK]]": "true" if verdict.get("wait_time_ok") else "false",
        "[[DIALOGUE_TAIL]]": tail,
    }
    for k, v in repl.items():
        sys = sys.replace(k, v)
    return [{"role": "system", "content": sys},
            {"role": "user", "content": "Respond now as the student, in character. JSON only."}]


def _call_openrouter(messages: list[dict[str, str]], key: str, temperature: float) -> str:
    body = json.dumps({
        "model": STUDENT_MODEL,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": 200,
        "response_format": {"type": "json_object"},
    }).encode("utf-8")
    rq = urllib.request.Request(OPENROUTER_URL, data=body, method="POST", headers={
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://chalk-and-chance.pages.dev",
        "X-Title": "Chalk & Chance",
    })
    with urllib.request.urlopen(rq, timeout=15) as r:
        data = json.loads(r.read().decode("utf-8"))
    return data["choices"][0]["message"]["content"]


def _parse_student(raw: str) -> dict[str, str]:
    raw = raw.strip()
    if "{" in raw and "}" in raw:
        raw = raw[raw.find("{"): raw.rfind("}") + 1]
    obj = json.loads(raw)
    return {"text": str(obj.get("text", "")).strip(), "emotion_shown": str(obj.get("emotion_shown", "thinking")).strip()}


# words that would mean the student leaked the resolution while unresolved
_LEAK_PATTERNS = [
    r"\bi (get|got) it now\b", r"\bnow i understand\b", r"\bso (it'?s|the answer is)\b",
    r"\bsmaller (piece|share)s? .* (bigger|larger)\b", r"\b1/4 is (bigger|larger)\b",
    r"\bmore pieces .* smaller\b", r"\byou'?re right\b", r"\bi was wrong\b",
]


def _validate_student(text: str, persona: dict[str, Any], resolved: bool, grade_band: str) -> tuple[bool, str]:
    """Deterministic post-gen guardrail (GAME_CONCEPT 7.5 #6). Reject ->regenerate once."""
    t = text.strip()
    if not t:
        return False, "empty"
    # length cap by grade band (younger = shorter)
    cap = 220 if "grade_5" in grade_band or "grade_4" in grade_band else 280
    if len(t) > cap or t.count(".") + t.count("!") + t.count("?") > 3:
        return False, "too long for grade band"
    if not resolved:
        low = t.lower()
        win_line = str(persona.get("win_line", "")).lower()
        for pat in _LEAK_PATTERNS:
            if re.search(pat, low):
                return False, f"leaked resolution while unresolved ({pat})"
        # near-verbatim win line is also a leak
        if win_line and len(win_line) > 20 and win_line[:25] in low:
            return False, "echoed win_line while unresolved"
    return True, "ok"


# --- Adaptive LLM coach (Coach Vee) ------------------------------------------
# Contingent, specific, FADING, next-step feedback generated from the live transcript
# (the evidence-based driver of sim-to-classroom transfer). Falls back to the canned tip.

COACH_TEMPLATE = (ROOT / "tools" / "coach_prompt.txt").read_text(encoding="utf-8")
COACH_MODEL = os.environ.get("OPENROUTER_COACH_MODEL", "google/gemini-2.5-flash-lite")


def _coach_messages(req: TurnRequest, persona: dict[str, Any], verdict: dict[str, Any]) -> list[dict[str, str]]:
    rs = req.runtime_state
    tag = verdict["move_tags"][0] if verdict["move_tags"] else ""
    hist = "\n".join(
        f'- {h.get("tag","?")}  [targets={"true" if h.get("targets") else "false"}]'
        for h in req.move_history[-6:]) or "(this is the first move)"
    tail = "\n".join(f'{d.get("speaker","?")}: {d.get("text","")}' for d in req.dialogue_tail[-6:]) or "(start of conversation)"
    sys = COACH_TEMPLATE
    repl = {
        "[[TARGET_BEHAVIOR]]": str(req.target_behavior or persona.get("target_label", "the target teaching skill")),
        "[[WIN_MOVES]]": ", ".join(req.win_moves) or ", ".join(persona.get("win_moves", [])),
        "[[RESOLVED]]": "true" if rs.get("misconception_resolved", False) else "false",
        "[[TURN]]": str(int(rs.get("turns_elapsed", len(req.move_history) + 1))),
        "[[MOVE_TAG]]": tag or "(spoke)",
        "[[TARGETS]]": "IS" if verdict.get("targets_misconception") else "is NOT",
        "[[WAIT_OK]]": "true" if verdict.get("wait_time_ok") else "false",
        "[[UNDERSTANDING]]": str(round(float(rs.get("understanding", 0.15)), 2)),
        "[[MOVE_HISTORY]]": hist,
        "[[DIALOGUE_TAIL]]": tail,
    }
    for k, v in repl.items():
        sys = sys.replace(k, v)
    return [{"role": "system", "content": sys},
            {"role": "user", "content": "Give your one coaching note now. JSON only."}]


def make_coach(req: TurnRequest, verdict: dict[str, Any], persona: dict[str, Any]) -> str:
    key = _openrouter_key()
    if not key or req.model_profile == "stub":
        return _coach_tip(verdict)
    try:
        raw = _call_openrouter(_coach_messages(req, persona, verdict), key, 0.4)
        raw = raw[raw.find("{"): raw.rfind("}") + 1]
        tip = str(json.loads(raw).get("coach_tip", "")).strip()
        return tip or _coach_tip(verdict)
    except Exception as exc:
        print(f"[coach] openrouter failed: {exc}")
        return _coach_tip(verdict)


def generate_student(req: TurnRequest, verdict: dict[str, Any]) -> dict[str, str]:
    """Dispatcher: OpenRouter/Gemini if a key is configured, else the canned fallback.
    Re-rolls once (cooler) if the post-gen validator rejects the utterance."""
    key = _openrouter_key()
    if not key or req.model_profile == "stub":
        return _canned_student(req, verdict)
    persona = _load_persona(req)
    name = persona.get("display_name", "Student")
    resolved = bool(req.runtime_state.get("misconception_resolved", False))
    grade = str(persona.get("grade_band", ""))
    messages = _build_messages(req, persona, verdict)
    for attempt, temp in enumerate((0.75, 0.4)):
        try:
            out = _parse_student(_call_openrouter(messages, key, temp))
        except Exception as exc:  # network / parse / key error -> fall back
            print(f"[student] openrouter attempt {attempt} failed: {exc}")
            break
        ok, why = _validate_student(out["text"], persona, resolved, grade)
        if ok:
            return {"speaker": name, "text": out["text"], "emotion_shown": out.get("emotion_shown", "thinking")}
        print(f"[student] validator rejected (attempt {attempt}): {why}")
        messages = messages + [{"role": "system", "content": f"That reply was rejected: {why}. Stay in your misconception, stay in grade-band, 1-2 short sentences. Try again, JSON only."}]
    fb = _canned_student(req, verdict)
    fb["speaker"] = name
    return fb


@app.post("/turn")
def turn(req: TurnRequest) -> dict[str, Any]:
    # Free-typed teacher talk: classify it to one move tag, then judge as usual.
    classified = ""
    if req.teacher_move.input_mode == "free_text" and (req.teacher_move.text or "").strip():
        classified = classify_move(req.teacher_move.text)
        req.teacher_move.menu_tag = classified
    verdict = judge(req.teacher_move, req.win_moves)
    if classified:
        verdict["classified_tag"] = classified
    row = verdict.pop("_row")
    deltas = {
        "understanding": row.get("understanding", 0.0),
        "trust": row.get("trust", 0.0),
        "engagement": row.get("engagement", 0.0),
        "order": row.get("order", 0.0),
        "composure": row.get("composure", 0.0),
    }
    # Student utterance and the adaptive coach note are independent LLM calls; run them
    # concurrently so a turn costs ~one call of latency instead of two.
    from concurrent.futures import ThreadPoolExecutor
    persona = _load_persona(req)
    with ThreadPoolExecutor(max_workers=2) as ex:
        f_student = ex.submit(generate_student, req, verdict)
        f_coach = ex.submit(make_coach, req, verdict, persona)
        student = f_student.result()
        coach = f_coach.result()
    return {
        "session_id": req.session_id,
        "judge": verdict,
        "meter_deltas": deltas,
        "student_utterance": student,
        "coach_tip": coach,
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


# --- ElevenLabs TTS (child-ish per-persona voices) ---------------------------
# Voice ids were created via Voice Design (tools, one-off) and stored in
# data/voice_profiles.json: { persona_id: elevenlabs_voice_id }. /tts returns raw
# mp3 bytes so Godot can play them directly via AudioStreamMP3.

from fastapi.responses import Response

_VOICE_PROFILES_PATH = ROOT / "data" / "voice_profiles.json"


def _eleven_key() -> str | None:
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if key:
        return key
    for p in (os.environ.get("ELEVENLABS_API_KEY_FILE", ""),
              str(pathlib.Path.home() / "Desktop" / "elevanlabs_API.txt"),
              str(pathlib.Path.home() / "Desktop" / "elevenlabs_API.txt")):
        if p and pathlib.Path(p).is_file():
            return pathlib.Path(p).read_text(encoding="utf-8").strip()
    return None


def _voice_profiles() -> dict[str, str]:
    try:
        return json.loads(_VOICE_PROFILES_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {}


# emotion_shown -> (stability, style): lower stability + higher style = more expressive
_EMO_SETTINGS = {
    "neutral": (0.50, 0.30), "thinking": (0.50, 0.30), "curious": (0.42, 0.45),
    "engaged": (0.40, 0.50), "excited": (0.30, 0.65), "proud": (0.38, 0.55),
    "warming": (0.45, 0.45), "shy": (0.55, 0.30), "confused": (0.45, 0.40),
    "anxious": (0.38, 0.45), "frustrated": (0.33, 0.55), "withdrawn": (0.58, 0.25),
    # synonyms the model sometimes emits
    "guarded": (0.58, 0.25), "nervous": (0.38, 0.45), "defiant": (0.33, 0.55),
}


class TTSRequest(BaseModel):
    persona_id: str = ""
    text: str = ""
    emotion: str = "neutral"
    model_id: str = "eleven_multilingual_v2"


@app.post("/tts")
def tts(req: TTSRequest):
    key = _eleven_key()
    voices = _voice_profiles()
    vid = voices.get(req.persona_id)
    if not key or not vid or not req.text.strip():
        return Response(status_code=204)  # no audio available; game stays silent, never errors
    stab, style = _EMO_SETTINGS.get(req.emotion.strip().lower(), (0.5, 0.35))
    body = json.dumps({
        "text": req.text,
        "model_id": req.model_id,
        "voice_settings": {"stability": stab, "similarity_boost": 0.75, "style": style, "use_speaker_boost": True},
    }).encode()
    rq = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{vid}?output_format=mp3_44100_128",
        data=body, method="POST",
        headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    try:
        audio = urllib.request.urlopen(rq, timeout=30).read()
        return Response(content=audio, media_type="audio/mpeg")
    except Exception as exc:
        print(f"[tts] elevenlabs failed: {exc}")
        return Response(status_code=204)


# --- Group check-in (/group_turn): monitoring a POD by conversing -------------
# A distinct mechanic from the 1:1 encounter: you sample a group, reveal its hidden
# collective state, press its shared reasoning, and equalize participation. Breadth +
# group dynamics, not a single-student misconception battle.

GROUP_TEMPLATE = (ROOT / "tools" / "group_prompt.txt").read_text(encoding="utf-8")

# monitoring move -> deterministic effects + the ECD competency it evidences
GROUP_DELTAS = {
    "observe":      {"understanding": 0.00, "participation": 0.00, "reveal": True,  "construct": "group_monitoring", "targets": True},
    "probe":        {"understanding": 0.03, "participation": 0.00, "reveal": True,  "construct": "formative_check",  "targets": True},
    "press":        {"understanding": 0.12, "participation": 0.00, "reveal": False, "construct": "group_monitoring", "targets": True, "needs_reveal": True},
    "redistribute": {"understanding": 0.02, "participation": 0.20, "reveal": False, "construct": "status_treatment", "targets": True},
    "move_on":      {"understanding": 0.00, "participation": 0.00, "reveal": False, "construct": "",                "targets": False},
}
GROUP_MOVE_DESC = {
    "observe": "just listening to the group", "probe": "asked the group to show their thinking",
    "press": "pushed the group's idea further", "redistribute": "pulled in a quieter member by name",
    "move_on": "moving on to another group",
}


class GroupTurnRequest(BaseModel):
    session_id: str = "grp"
    members: list[dict[str, Any]] = []          # [{persona_id,name,talkativeness}]
    shared_concept: str = ""
    collective_status: str = "shared_misconception"
    collective_reasoning: str = ""
    group_state: dict[str, Any] = {}            # {understanding, participation_balance, revealed}
    teacher_move: dict[str, Any] = {}           # {menu_tag}
    model_profile: str = "openrouter_gemini"


def group_judge(tag: str, revealed: bool) -> dict[str, Any]:
    row = GROUP_DELTAS.get(tag, {})
    du = float(row.get("understanding", 0.0))
    targets = bool(row.get("targets", False))
    if tag == "press" and not revealed:   # pressing a group whose thinking you haven't surfaced does little
        du, targets = 0.0, False
    return {"move_tag": tag, "understanding_delta": du, "participation_delta": float(row.get("participation", 0.0)),
            "reveal": bool(row.get("reveal", False)), "construct": row.get("construct", ""), "targets": targets}


def _group_speaker(members: list[dict[str, Any]], tag: str) -> str:
    if not members:
        return "The group"
    if tag == "redistribute":   # the quietest member is invited in
        m = min(members, key=lambda x: float(x.get("talkativeness", 0.5)))
    else:                       # the dominant member answers for everyone
        m = max(members, key=lambda x: float(x.get("talkativeness", 0.5)))
    return str(m.get("name", "A student"))


def _group_messages(req: GroupTurnRequest, tag: str, speaker: str) -> list[dict[str, str]]:
    gs = req.group_state or {}
    members = "\n".join(f"- {m.get('name','?')} (talkativeness {m.get('talkativeness',0.5)})" for m in req.members) or "- a few students"
    sys = GROUP_TEMPLATE
    repl = {
        "[[MEMBERS]]": members,
        "[[STATUS_DESC]]": f"{req.collective_status} (concept: {req.shared_concept})",
        "[[COLLECTIVE_REASONING]]": req.collective_reasoning or "(they are still figuring it out)",
        "[[REVEALED]]": "revealed" if gs.get("revealed", False) else "still hidden",
        "[[PARTICIPATION]]": f"balance {round(float(gs.get('participation_balance', 0.4)), 2)} (lower = one student dominates)",
        "[[SPEAKER_RULE]]": f"{speaker} speaks this turn.",
        "[[MOVE_TAG]]": tag or "(observes)",
        "[[MOVE_DESC]]": GROUP_MOVE_DESC.get(tag, "addresses the group"),
    }
    for k, v in repl.items():
        sys = sys.replace(k, v)
    return [{"role": "system", "content": sys},
            {"role": "user", "content": "Respond now as the group member, in character. JSON only."}]


def _canned_group(tag: str, speaker: str) -> dict[str, str]:
    canned = {
        "observe": "I think we should add them... wait, no, compare them first, right?",
        "probe": "We said the bigger bottom number means the bigger fraction, so we picked 1/8.",
        "press": "Hmm... if we cut it into more pieces, wouldn't each piece be smaller though?",
        "redistribute": "...um, I actually thought 1/4 might be bigger, but I wasn't sure.",
        "move_on": "Okay, we'll keep working.",
    }
    return {"speaker": speaker, "text": canned.get(tag, "We're still working on it."), "emotion_shown": "thinking"}


def generate_group(req: GroupTurnRequest, tag: str, speaker: str) -> dict[str, str]:
    key = _openrouter_key()
    if not key or req.model_profile == "stub" or tag == "move_on":
        return _canned_group(tag, speaker)
    try:
        raw = _call_openrouter(_group_messages(req, tag, speaker), key, 0.7)
        raw = raw[raw.find("{"): raw.rfind("}") + 1]
        o = json.loads(raw)
        return {"speaker": str(o.get("speaker", speaker)).strip() or speaker,
                "text": str(o.get("text", "")).strip() or _canned_group(tag, speaker)["text"],
                "emotion_shown": str(o.get("emotion_shown", "thinking")).strip()}
    except Exception as exc:
        print(f"[group] fallback ({exc})")
        return _canned_group(tag, speaker)


def _group_coach(tag: str, revealed: bool) -> str:
    tips = {
        "observe": "Good - you listened first. Now you know where they are; surface it with a probe.",
        "probe": "Nice formative check. Their thinking is on the table now - press the crack, don't correct it.",
        "press": ("They are reasoning it through together. Keep pressing." if revealed
                  else "You pressed before you surfaced their thinking. Probe first so you know what to press on."),
        "redistribute": "Status move: you pulled in a quieter voice. That rebalances who gets to think.",
        "move_on": "Triage is real - you can't camp on one group. But check the silent groups before they drift.",
    }
    return tips.get(tag, "Sample the group, then decide: surface, press, or rebalance.")


@app.post("/group_turn")
def group_turn(req: GroupTurnRequest) -> dict[str, Any]:
    tag = str((req.teacher_move or {}).get("menu_tag", "")).strip()
    revealed = bool((req.group_state or {}).get("revealed", False))
    verdict = group_judge(tag, revealed)
    speaker = _group_speaker(req.members, tag)
    utter = generate_group(req, tag, speaker)
    return {
        "session_id": req.session_id,
        "judge": verdict,
        "group_utterance": utter,
        "coach_tip": _group_coach(tag, revealed),
    }
