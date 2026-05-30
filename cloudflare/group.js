// /group_turn ported from app.py: monitoring a POD by conversing (distinct from 1:1).
// Deterministic monitoring judge + a collective LLM group utterance. OpenRouter key is a
// Worker secret.
import { GROUP_PROMPT } from "./gamedata.js";

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

const GROUP_DELTAS = {
  observe:      { understanding: 0.0,  participation: 0.0, reveal: true,  construct: "group_monitoring", targets: true },
  probe:        { understanding: 0.03, participation: 0.0, reveal: true,  construct: "formative_check",  targets: true },
  press:        { understanding: 0.12, participation: 0.0, reveal: false, construct: "group_monitoring", targets: true, needs_reveal: true },
  redistribute: { understanding: 0.02, participation: 0.2, reveal: false, construct: "status_treatment", targets: true },
  move_on:      { understanding: 0.0,  participation: 0.0, reveal: false, construct: "",                targets: false },
};
const GROUP_MOVE_DESC = {
  observe: "just listening to the group", probe: "asked the group to show their thinking",
  press: "pushed the group's idea further", redistribute: "pulled in a quieter member by name",
  move_on: "moving on to another group",
};

function groupJudge(tag, revealed) {
  const row = GROUP_DELTAS[tag] || {};
  let du = row.understanding || 0.0;
  let targets = !!row.targets;
  if (tag === "press" && !revealed) { du = 0.0; targets = false; }
  return { move_tag: tag, understanding_delta: du, participation_delta: row.participation || 0.0,
    reveal: !!row.reveal, construct: row.construct || "", targets };
}

function groupSpeaker(members, tag) {
  if (!members || !members.length) return "The group";
  const m = tag === "redistribute"
    ? members.reduce((a, b) => ((a.talkativeness ?? 0.5) <= (b.talkativeness ?? 0.5) ? a : b))
    : members.reduce((a, b) => ((a.talkativeness ?? 0.5) >= (b.talkativeness ?? 0.5) ? a : b));
  return String(m.name || "A student");
}

function groupMessages(body, tag, speaker) {
  const gs = body.group_state || {};
  const members = (body.members || []).map((m) => `- ${m.name || "?"} (talkativeness ${m.talkativeness ?? 0.5})`).join("\n") || "- a few students";
  const repl = {
    "[[MEMBERS]]": members,
    "[[STATUS_DESC]]": `${body.collective_status || "shared_misconception"} (concept: ${body.shared_concept || ""})`,
    "[[COLLECTIVE_REASONING]]": body.collective_reasoning || "(they are still figuring it out)",
    "[[REVEALED]]": gs.revealed ? "revealed" : "still hidden",
    "[[PARTICIPATION]]": `balance ${Math.round((gs.participation_balance ?? 0.4) * 100) / 100} (lower = one student dominates)`,
    "[[SPEAKER_RULE]]": `${speaker} speaks this turn.`,
    "[[MOVE_TAG]]": tag || "(observes)",
    "[[MOVE_DESC]]": GROUP_MOVE_DESC[tag] || "addresses the group",
  };
  let sys = GROUP_PROMPT;
  for (const [k, v] of Object.entries(repl)) sys = sys.split(k).join(v);
  return [{ role: "system", content: sys },
    { role: "user", content: "Respond now as the group member, in character. JSON only." }];
}

function cannedGroup(tag, speaker) {
  const c = {
    observe: "I think we should add them... wait, no, compare them first, right?",
    probe: "We said the bigger bottom number means the bigger fraction, so we picked 1/8.",
    press: "Hmm... if we cut it into more pieces, wouldn't each piece be smaller though?",
    redistribute: "...um, I actually thought 1/4 might be bigger, but I wasn't sure.",
    move_on: "Okay, we'll keep working.",
  };
  return { speaker, text: c[tag] || "We're still working on it.", emotion_shown: "thinking" };
}

async function generateGroup(body, tag, speaker, key) {
  if (!key || tag === "move_on") return cannedGroup(tag, speaker);
  try {
    const r = await fetch(OPENROUTER_URL, {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model: "google/gemini-2.5-flash-lite", messages: groupMessages(body, tag, speaker),
        temperature: 0.7, max_tokens: 160, response_format: { type: "json_object" } }),
    });
    if (!r.ok) throw new Error(`openrouter ${r.status}`);
    const raw = (await r.json()).choices[0].message.content;
    const o = JSON.parse(raw.slice(raw.indexOf("{"), raw.lastIndexOf("}") + 1));
    return { speaker: String(o.speaker || speaker).trim() || speaker,
      text: String(o.text || "").trim() || cannedGroup(tag, speaker).text,
      emotion_shown: String(o.emotion_shown || "thinking").trim() };
  } catch (_e) {
    return cannedGroup(tag, speaker);
  }
}

function groupCoach(tag, revealed) {
  const t = {
    observe: "Good - you listened first. Now you know where they are; surface it with a probe.",
    probe: "Nice formative check. Their thinking is on the table now - press the crack, don't correct it.",
    press: revealed ? "They are reasoning it through together. Keep pressing."
      : "You pressed before you surfaced their thinking. Probe first so you know what to press on.",
    redistribute: "Status move: you pulled in a quieter voice. That rebalances who gets to think.",
    move_on: "Triage is real - you can't camp on one group. But check the silent groups before they drift.",
  };
  return t[tag] || "Sample the group, then decide: surface, press, or rebalance.";
}

export async function handleGroupTurn(req, env) {
  const body = await req.json();
  const tag = String((body.teacher_move || {}).menu_tag || "").trim();
  const revealed = !!(body.group_state || {}).revealed;
  const verdict = groupJudge(tag, revealed);
  const speaker = groupSpeaker(body.members || [], tag);
  const utter = await generateGroup(body, tag, speaker, (env.OPENROUTER_API_KEY || "").trim());
  return { session_id: body.session_id || "grp", judge: verdict, group_utterance: utter,
    coach_tip: groupCoach(tag, revealed) };
}
