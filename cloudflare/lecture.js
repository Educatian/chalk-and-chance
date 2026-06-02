// /lecture_turn: scenario-aware classroom reactions for direct-instruction mode.
// Scoring stays in Godot; this endpoint only generates the visible class/student
// reaction and Coach Vee's pacing feedback.

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

const MOVE_DESC = {
  present: "presented the next chunk of content",
  ask: "asked the highlighted student a check-for-understanding question",
  wait: "paused to give the class think time",
  reexplain: "re-explained the tricky step another way",
  poll: "ran a whole-class check",
};

function scenarioBrief(body) {
  const sc = body.scenario_context || {};
  const active = sc.active_student || {};
  const focus = sc.lecture_focus || {};
  const objectives = Array.isArray(sc.objectives) && sc.objectives.length
    ? sc.objectives.map((o) => `- ${String(o)}`).join("\n")
    : "- pace the lecture, keep attention, and check understanding";
  const roster = Array.isArray(sc.roster) && sc.roster.length
    ? sc.roster.map((s) => `- ${s.name || s.persona_id || "student"}${s.target_label ? `: ${s.target_label}` : ""}`).join("\n")
    : "- roster not specified";
  const pieces = [
    `scenario_id: ${body.scenario_id || sc.id || "unknown"}`,
    `lesson: ${sc.title || "Current lecture"}`,
    `format: ${sc.format || "lecture"}${sc.arrangement ? ` (${sc.arrangement})` : ""}`,
    "lesson objectives:",
    objectives,
    focus.big_idea ? `big idea: ${focus.big_idea}` : "",
    focus.common_confusion ? `common confusion: ${focus.common_confusion}` : "",
    focus.check_for_understanding_prompt ? `sample check-for-understanding: ${focus.check_for_understanding_prompt}` : "",
    "roster:",
    roster,
  ].filter(Boolean);
  if (active.name || active.target_label || active.opening_line) {
    pieces.push(`highlighted student: ${active.name || active.persona_id || "student"}`);
    if (active.target_label) pieces.push(`highlighted student need: ${active.target_label}`);
    if (active.opening_line) pieces.push(`highlighted starting idea/behavior: ${active.opening_line}`);
  }
  return pieces.join("\n");
}

async function callOpenRouter(messages, key) {
  const r = await fetch(OPENROUTER_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
      "HTTP-Referer": "https://chalk-and-chance.pages.dev",
      "X-Title": "Chalk & Chance",
    },
    body: JSON.stringify({
      model: "google/gemini-2.5-flash-lite",
      messages,
      temperature: 0.55,
      max_tokens: 220,
      response_format: { type: "json_object" },
    }),
  });
  if (!r.ok) throw new Error(`openrouter ${r.status}`);
  return (await r.json()).choices[0].message.content;
}

function lectureMessages(body, tag) {
  const state = body.class_state || {};
  const active = (body.scenario_context || {}).active_student || {};
  const move = body.teacher_move || {};
  const teacherText = String(move.text || "").trim();
  const tail = (body.dialogue_tail || []).slice(-6)
    .map((d) => `${d.speaker || "?"}: ${d.text || ""}`).join("\n") || "(start of lecture)";
  const sys = [
    "You simulate a direct-instruction classroom for a beginner teacher game.",
    "Return ONLY JSON with this shape:",
    '{"reaction":{"speaker":"Class or student name","text":"1 short in-character classroom reaction","scope":"class|student","emotion_shown":"engaged|thinking|confused|withdrawn|excited"},"coach_tip":"one concise Coach Vee note about pacing/checking understanding"}',
    "",
    "# CURRENT TEACHER MOVE",
    `${tag}: ${MOVE_DESC[tag] || "addressed the class"}`,
    teacherText ? `teacher's exact words: ${teacherText}` : "teacher used a menu move, not typed words",
    "",
    "# CLASS STATE",
    `progress: ${state.progress ?? 0}`,
    `comprehension: ${state.comprehension ?? 0}`,
    `attention: ${state.attention ?? 0}`,
    `composure: ${state.composure ?? 0}`,
    `consecutive_present: ${state.consecutive_present ?? 0}`,
    `wait_ok: ${state.wait_ok ? "true" : "false"}`,
    "",
    "# SCENARIO-SPECIFIC LESSON CONTEXT",
    scenarioBrief(body),
    "",
    "# RECENT LECTURE HISTORY",
    tail,
    "",
    "# BEGINNER LEARNING FRAME",
    "The player is learning how to begin a lesson, what each move does, and how lecture pacing becomes evidence of student thinking.",
    "Coach Vee should name the teaching concept in plain English: chunking, wait time, check-for-understanding, responsive re-explanation, or whole-class accountability.",
    "Rules: keep the reaction lesson-specific, do not teach or imply the final content answer, and do not change scores. If the teacher is over-presenting, make attention/comprehension concerns visible. If they check understanding well, show the class becoming more accountable. The student may repeat a starting misconception, hesitate, or describe confusion, but must not resolve the misconception for the player.",
  ].join("\n");
  const user = active.name
    ? `Generate the next classroom reaction. If appropriate, let ${active.name} speak.`
    : "Generate the next classroom reaction.";
  return [{ role: "system", content: sys }, { role: "user", content: user }];
}

function cannedLecture(body, tag) {
  const active = (body.scenario_context || {}).active_student || {};
  const name = active.name || "A student";
  const state = body.class_state || {};
  const gap = Number(state.progress || 0) - Number(state.comprehension || 0);
  const map = {
    present: gap > 25
      ? { speaker: "Class", text: "A few students keep copying, but their faces say the step is moving faster than their thinking.", scope: "class", emotion_shown: "confused" }
      : { speaker: "Class", text: "Most students track the new chunk, though a few are waiting to see what it connects to.", scope: "class", emotion_shown: "thinking" },
    ask: { speaker: name, text: active.opening_line || "I can try, but I need to say how I was thinking first.", scope: "student", emotion_shown: gap > 25 ? "confused" : "engaged" },
    wait: { speaker: "Class", text: "The room gets quiet for a beat, and more students start forming an answer instead of watching one person.", scope: "class", emotion_shown: "thinking" },
    reexplain: { speaker: "Class", text: "The alternate explanation gives several students a way back into the idea.", scope: "class", emotion_shown: "engaged" },
    poll: { speaker: "Class", text: "Everyone has to commit to an answer, so the hidden confusion becomes visible.", scope: "class", emotion_shown: "excited" },
  };
  const coach = {
    present: gap > 25 ? "You are ahead of their comprehension. Pause the content and check before adding more." : "That chunk was manageable. Follow it with a check so attention turns into evidence.",
    ask: state.wait_ok ? "Good check with wait time. Now use the answer as evidence, not as a performance moment." : "The question helps, but give more wait time before choosing a student.",
    wait: "Wait time turns the room from watching to thinking. Follow it with a question or whole-class check.",
    reexplain: "Responsive repair is the right move when the lesson has outrun comprehension.",
    poll: "A whole-class check makes everyone accountable and shows you what to reteach.",
  };
  return { reaction: map[tag] || { speaker: "Class", text: "The class keeps working.", scope: "class", emotion_shown: "thinking" },
    coach_tip: coach[tag] || "Keep pacing the lecture from evidence, not hope." };
}

function leaksLectureAnswer(text) {
  const t = String(text || "").toLowerCase();
  return [
    /(denominator|bottom number).*(smaller|bigger|larger).*(piece|pieces|fraction|slice|slices)/,
    /(denominator|bottom number).*(bigger|larger).*(piece|pieces|slice|slices).*(smaller|skinnier)/,
    /(piece|pieces|slice|slices).*(smaller|bigger|larger).*(denominator|bottom number)/,
    /bigger denominator .* smaller/,
    /bigger bottom number .* smaller/,
    /more pieces .* smaller/,
    /one fourth .* bigger/,
    /1\/4 .* bigger/,
    /i get it now/,
  ].some((p) => p.test(t));
}

function parseLecture(raw, fallback) {
  let s = String(raw || "").trim();
  if (s.includes("{") && s.includes("}")) s = s.slice(s.indexOf("{"), s.lastIndexOf("}") + 1);
  const o = JSON.parse(s);
  const r = o.reaction || {};
  const text = String(r.text || fallback.reaction.text || "The class keeps working.").trim();
  if (leaksLectureAnswer(text)) return fallback;
  return {
    reaction: {
      speaker: String(r.speaker || fallback.reaction.speaker || "Class").trim(),
      text,
      scope: String(r.scope || fallback.reaction.scope || "class").trim(),
      emotion_shown: String(r.emotion_shown || fallback.reaction.emotion_shown || "thinking").trim(),
    },
    coach_tip: String(o.coach_tip || fallback.coach_tip || "Use the class evidence to choose the next move.").trim(),
  };
}

export async function handleLectureTurn(req, env) {
  const body = await req.json();
  const tag = String((body.teacher_move || {}).menu_tag || "").trim();
  const fallback = cannedLecture(body, tag);
  const key = (env.OPENROUTER_API_KEY || "").trim();
  if (!key || body.model_profile === "stub") {
    return { session_id: body.session_id || "lecture", ...fallback };
  }
  try {
    const raw = await callOpenRouter(lectureMessages(body, tag), key);
    return { session_id: body.session_id || "lecture", ...parseLecture(raw, fallback) };
  } catch (_e) {
    return { session_id: body.session_id || "lecture", ...fallback };
  }
}
