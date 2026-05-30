// /turn pipeline ported from tools/llm_backend/app.py so the deployed web game gets
// real Gemini students (judge-before-generate + frozen-persona anti-sycophancy + adaptive
// coach). OpenRouter key is a Worker secret (OPENROUTER_API_KEY); never reaches the client.
import { RUBRIC, PERSONAS, STUDENT_PROMPT, COACH_PROMPT } from "./gamedata.js";

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const MOVE_TAGS = ["elicit", "extend", "revoice", "tell", "praise", "redirect", "wait", "connect"];

const lst = (v) => (Array.isArray(v) ? v.join("; ") : String(v ?? ""));

// --- deterministic judge (win-move-gated) -----------------------------------
function judge(move, winMoves) {
  const tag = (move.menu_tag || "").trim();
  const waitOk = (move.wait_time_ms || 0) >= RUBRIC.wait.threshold_ms;
  let row = { ...(tag === "wait" ? (waitOk ? RUBRIC.wait.met : RUBRIC.wait.missed) : (RUBRIC.deltas[tag] || {})) };
  let targets = !!row.targets_misconception;
  if (winMoves && winMoves.length && tag && !winMoves.includes(tag)) {
    targets = false;
    row.understanding = 0.0;
  }
  row.targets_misconception = targets;
  return {
    move_tags: tag ? [tag] : [],
    targets_misconception: targets,
    feedback_type: row.feedback_type || "none",
    wait_time_ok: waitOk,
    _row: row,
  };
}

// --- OpenRouter call ---------------------------------------------------------
async function callOpenRouter(messages, key, model, temperature, maxTokens) {
  const r = await fetch(OPENROUTER_URL, {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json",
      "HTTP-Referer": "https://chalk-and-chance.pages.dev", "X-Title": "Chalk & Chance" },
    body: JSON.stringify({ model, messages, temperature, max_tokens: maxTokens,
      response_format: { type: "json_object" } }),
  });
  if (!r.ok) throw new Error(`openrouter ${r.status}`);
  const d = await r.json();
  return d.choices[0].message.content;
}

// --- free-text classifier ----------------------------------------------------
function heuristicClassify(text) {
  const t = (text || "").toLowerCase().trim();
  if (!t) return "wait";
  if (/(how did you|why do you|can you show me|what makes you|how do you)/.test(t)) return "elicit";
  if (t.includes("?") && /(what if|what about|and then|so what|what else)/.test(t)) return "extend";
  if (/^(so you|so what you|you're saying|what i hear)/.test(t)) return "revoice";
  if (/(good job|nice work|i like how|well done|great)/.test(t)) return "praise";
  if (/(settle|focus|quiet|back to|stop|eyes up)/.test(t)) return "redirect";
  if (/(tell you about|what do you like|outside class|good at)/.test(t)) return "connect";
  if (/(the answer is|actually it|here's how|let me show|because the)/.test(t)) return "tell";
  return "elicit";
}
async function classifyMove(text, key) {
  if (!key) return heuristicClassify(text);
  try {
    const sys = "You label a teacher's utterance to a student with EXACTLY ONE move tag from: " +
      "elicit, extend, revoice, tell, praise, redirect, wait, connect. " +
      'elicit=asks how/why they think; extend=pushes their idea further; revoice=restates their thinking; ' +
      'tell=states the answer/explains directly; praise=praises; redirect=manages behavior; wait=silence; ' +
      'connect=asks about their life/interests. Return ONLY JSON {"tag":"<one tag>"}.';
    const raw = await callOpenRouter(
      [{ role: "system", content: sys }, { role: "user", content: String(text).slice(0, 500) }],
      key, "google/gemini-2.5-flash-lite", 0.0, 20);
    const tag = String(JSON.parse(raw.slice(raw.indexOf("{"), raw.lastIndexOf("}") + 1)).tag || "").trim().toLowerCase();
    return MOVE_TAGS.includes(tag) ? tag : heuristicClassify(text);
  } catch (_e) {
    return heuristicClassify(text);
  }
}

// --- student generation (frozen persona, anti-sycophancy) --------------------
function studentMessages(req, persona, verdict) {
  const ks = persona.knowledge_state || {};
  const bt = persona.behavior_tendencies || {};
  const rs = req.runtime_state || {};
  const tag = verdict.move_tags[0] || "";
  const tail = (req.dialogue_tail || []).slice(-6).map((d) => `${d.speaker || "?"}: ${d.text || ""}`).join("\n") || "(start of conversation)";
  const repl = {
    "[[PERSONA_JSON]]": JSON.stringify({ display_name: persona.display_name, grade_band: persona.grade_band,
      subject_context: persona.subject_context, traits: persona.traits, behavior_tendencies: bt }, null, 2),
    "[[FROZEN_MISCONCEPTION]]": String(ks.frozen_misconception || ""),
    "[[FACTS_KNOWN]]": lst(ks.correct_facts_known || []),
    "[[FACTS_NOT_KNOWN]]": lst(ks.facts_NOT_known || []),
    "[[WILL_NOT_INVENT]]": String(ks.will_not_invent_beyond || "the lesson's grade level"),
    "[[GRADE_BAND]]": String(persona.grade_band || "grade-level"),
    "[[RESPONSE_LENGTH]]": String(bt.default_response_length || "1-2 sentences"),
    "[[FLIP_POLICY]]": String(persona.answer_flip_policy || "Keep your stated understanding unless you reason it out yourself."),
    "[[RESOLVED]]": rs.misconception_resolved ? "true" : "false",
    "[[EMOTION_BASELINE]]": String(persona.emotion_baseline || "neutral"),
    "[[CURRENT_EMOTION]]": String(rs.emotion || persona.emotion_baseline || "neutral"),
    "[[ESCALATION]]": lst(persona.escalation_triggers || []),
    "[[DEESCALATION]]": lst(persona.deescalation_moves || []),
    "[[HIDDEN_NEED]]": String(persona.hidden_need || ""),
    "[[UNDERSTANDING]]": String(Math.round((rs.understanding ?? 0.15) * 100) / 100),
    "[[TRUST]]": String(Math.round((rs.trust_in_teacher ?? 0.5) * 100) / 100),
    "[[ENGAGEMENT]]": String(Math.round((rs.engagement ?? 0.4) * 100) / 100),
    "[[MOVE_TAG]]": tag || "(said something)",
    "[[TARGETS]]": verdict.targets_misconception ? "IS" : "is NOT",
    "[[WAIT_OK]]": verdict.wait_time_ok ? "true" : "false",
    "[[DIALOGUE_TAIL]]": tail,
  };
  let sys = STUDENT_PROMPT;
  for (const [k, v] of Object.entries(repl)) sys = sys.split(k).join(v);
  return [{ role: "system", content: sys },
    { role: "user", content: "Respond now as the student, in character. JSON only." }];
}

const LEAK_PATTERNS = [
  /\bi (get|got) it now\b/, /\bnow i understand\b/, /\bso (it'?s|the answer is)\b/,
  /\bsmaller (piece|share)s? .* (bigger|larger)\b/, /\b1\/4 is (bigger|larger)\b/,
  /\bmore pieces .* smaller\b/, /\byou'?re right\b/, /\bi was wrong\b/,
];
function validateStudent(text, persona, resolved, grade) {
  const t = (text || "").trim();
  if (!t) return [false, "empty"];
  const cap = (grade.includes("grade_5") || grade.includes("grade_4")) ? 220 : 280;
  const sentences = (t.match(/[.!?]/g) || []).length;
  if (t.length > cap || sentences > 3) return [false, "too long for grade band"];
  if (!resolved) {
    const low = t.toLowerCase();
    for (const p of LEAK_PATTERNS) if (p.test(low)) return [false, "leaked resolution"];
    const win = String(persona.win_line || "").toLowerCase();
    if (win.length > 20 && low.includes(win.slice(0, 25))) return [false, "echoed win_line"];
  }
  return [true, "ok"];
}
function parseStudent(raw) {
  let s = raw.trim();
  if (s.includes("{") && s.includes("}")) s = s.slice(s.indexOf("{"), s.lastIndexOf("}") + 1);
  const o = JSON.parse(s);
  return { text: String(o.text || "").trim(), emotion_shown: String(o.emotion_shown || "thinking").trim() };
}
function cannedStudent(verdict, name) {
  const tag = verdict.move_tags[0] || "";
  const m = { elicit: "Um... okay. Let me try to explain how I was thinking about it.",
    extend: "Wait... when you put it that way, I'm not so sure my first answer was right.",
    revoice: "Yeah... that's what I meant.", tell: "Oh. Okay, I guess.", praise: "...thanks.",
    redirect: "Okay, sorry.", wait: verdict.wait_time_ok ? "...oh. Actually, maybe I had it backwards." : "..." };
  return { speaker: name, text: m[tag] || "...", emotion_shown: "guarded" };
}
async function generateStudent(req, persona, verdict, key) {
  const name = persona.display_name || "Student";
  if (!key) return cannedStudent(verdict, name);
  const resolved = !!(req.runtime_state || {}).misconception_resolved;
  const grade = String(persona.grade_band || "");
  let messages = studentMessages(req, persona, verdict);
  for (const temp of [0.75, 0.4]) {
    let out;
    try {
      out = parseStudent(await callOpenRouter(messages, key, "google/gemini-2.5-flash-lite", temp, 200));
    } catch (_e) { break; }
    const [ok, why] = validateStudent(out.text, persona, resolved, grade);
    if (ok) return { speaker: name, text: out.text, emotion_shown: out.emotion_shown };
    messages = [...messages, { role: "system", content: `That reply was rejected: ${why}. Stay in your misconception, grade-band, 1-2 short sentences. JSON only.` }];
  }
  return cannedStudent(verdict, name);
}

// --- adaptive coach ----------------------------------------------------------
function coachTip(verdict) {
  const tag = verdict.move_tags[0] || "";
  const tips = { elicit: "Good eliciting move. Press on the crack in his reasoning.",
    extend: "Nice press. He is reasoning it through himself.", revoice: "Revoicing makes his thinking public.",
    tell: "You took over the thinking; engagement dropped. Try eliciting first.",
    praise: "Name the specific behavior, not 'good job'.", redirect: "Use the least-intrusive redirect that works.",
    wait: "Hold the pause 3 to 5 seconds; let him fill the silence." };
  return tips[tag] || "Pick a teaching move.";
}
async function makeCoach(req, persona, verdict, key) {
  if (!key) return coachTip(verdict);
  try {
    const rs = req.runtime_state || {};
    const tag = verdict.move_tags[0] || "";
    const hist = (req.move_history || []).slice(-6).map((h) => `- ${h.tag || "?"}  [targets=${h.targets ? "true" : "false"}]`).join("\n") || "(this is the first move)";
    const tail = (req.dialogue_tail || []).slice(-6).map((d) => `${d.speaker || "?"}: ${d.text || ""}`).join("\n") || "(start of conversation)";
    const repl = {
      "[[TARGET_BEHAVIOR]]": String(req.target_behavior || persona.target_label || "the target teaching skill"),
      "[[WIN_MOVES]]": (req.win_moves || persona.win_moves || []).join(", "),
      "[[RESOLVED]]": rs.misconception_resolved ? "true" : "false",
      "[[TURN]]": String(rs.turns_elapsed || (req.move_history || []).length + 1),
      "[[MOVE_TAG]]": tag || "(spoke)",
      "[[TARGETS]]": verdict.targets_misconception ? "IS" : "is NOT",
      "[[WAIT_OK]]": verdict.wait_time_ok ? "true" : "false",
      "[[UNDERSTANDING]]": String(Math.round((rs.understanding ?? 0.15) * 100) / 100),
      "[[MOVE_HISTORY]]": hist, "[[DIALOGUE_TAIL]]": tail,
    };
    let sys = COACH_PROMPT;
    for (const [k, v] of Object.entries(repl)) sys = sys.split(k).join(v);
    const raw = await callOpenRouter([{ role: "system", content: sys },
      { role: "user", content: "Give your one coaching note now. JSON only." }], key, "google/gemini-2.5-flash-lite", 0.4, 120);
    const tip = String(JSON.parse(raw.slice(raw.indexOf("{"), raw.lastIndexOf("}") + 1)).coach_tip || "").trim();
    return tip || coachTip(verdict);
  } catch (_e) {
    return coachTip(verdict);
  }
}

// --- entry point -------------------------------------------------------------
export async function handleTurn(req, env) {
  const body = await req.json();
  const key = (env.OPENROUTER_API_KEY || "").trim();
  const move = body.teacher_move || {};
  let classified = "";
  if (move.input_mode === "free_text" && (move.text || "").trim()) {
    classified = await classifyMove(move.text, key);
    move.menu_tag = classified;
  }
  const verdict = judge(move, body.win_moves || []);
  const row = verdict._row; delete verdict._row;
  if (classified) verdict.classified_tag = classified;
  const deltas = {
    understanding: row.understanding || 0.0, trust: row.trust || 0.0, engagement: row.engagement || 0.0,
    order: row.order || 0.0, composure: row.composure || 0.0,
  };
  const persona = PERSONAS[body.active_persona_id] || body.frozen_persona || {};
  const [student, coach] = await Promise.all([
    generateStudent(body, persona, verdict, key),
    makeCoach(body, persona, verdict, key),
  ]);
  return { session_id: body.session_id || "web", judge: verdict, meter_deltas: deltas,
    student_utterance: student, coach_tip: coach };
}
