// Calibration against what the model actually said: every line the deployed Worker returned
// in the three hosted checks (docs/qa/korean-hosted-check.md) is replayed through the current
// filters with the context the fixed Worker would see. No network.
// Run: node --test cloudflare/test/replay.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { replay } from "./replay.mjs";
import { validateCoach } from "../locale.js";
import { handleTurn } from "../turn.js";

const rows = replay();
const key = (r) => `${r.set}/${r.persona}/${r.turn}`;

test("no line the model actually wrote is hard-rejected (no fixed line)", () => {
  const hard = rows.filter((r) => r.student.startsWith("HARD") || r.coach.startsWith("HARD"));
  assert.deepEqual(hard.map(key), []);
});

test("student verdicts: the real repeats are soft (one retry, then kept); everything else passes", () => {
  const model = rows.filter((r) => r.src === "model");
  assert.equal(model.length, 19);   // 8 + 4 + 6 Korean, 1 English
  const soft = model.filter((r) => r.student.startsWith("soft")).map(key).sort();
  assert.deepEqual(soft, ["set1/diego_ell/3", "set1/noah_g5_fractions/2", "set2/noah_g5_fractions/2"]);
  // a revoice invites restating: 민호's verbatim echo after "그러니까 네 말은…" is allowed
  assert.equal(rows.find((r) => key(r) === "set2/diego_ell/2").student, "pass");
  // with the move-on prompt rule (set 3), none of the model's replies repeated
  assert.ok(rows.filter((r) => r.set === "set3" && r.src === "model").every((r) => r.student === "pass"));
});

test("coach verdicts: model tips pass or are style-only (kept after a retry)", () => {
  const model = rows.filter((r) => r.coach_src === "model");
  assert.equal(model.length, 8);   // 7 Korean, 1 English
  assert.ok(model.every((r) => r.coach === "pass" || r.coach.startsWith("soft")));
});

test("plausible 민호 coach tips (한국어, 그림, naming the next move, longer) are accepted", () => {
  const tips = [
    ["elicit", "민호에게 생각 묻기를 한 건 좋았어요. 한국어로 말하기 어려워하니 그림으로 먼저 보여 주게 해 봐요."],
    ["elicit", "생각을 물어본 건 좋아요. 다음엔 기다려 주기로 민호가 한국어로 말할 시간을 줘요."],
    ["revoice", "되말하기로 민호의 생각을 들어 줬어요. 한국어 표현이 서툴러도 생각은 분명하니, 그림이나 손짓으로 먼저 보여 주게 하고 그다음에 말로 옮겨 보게 해요."],
    ["praise", "민호가 그림으로 설명한 걸 짚어서 칭찬했어요. 이제 그 그림을 한국어 한두 단어로 말해 보게 해요."],
  ];
  for (const [move, tip] of tips) assert.deepEqual(validateCoach(tip, true, move).slice(0, 1), [true], tip);
});

// --- the Worker end to end, with a stub for the model -------------------------------
const req = (body) => ({ json: async () => body });
function stub(studentReplies) {
  globalThis.fetch = async (url, init) => {
    const sys = JSON.parse(init.body).messages[0].content;
    const content = sys.includes("coach_tip") ? '{"coach_tip":"생각 묻기 좋았어요."}'
      : JSON.stringify({ text: studentReplies.shift() ?? "…", emotion_shown: "thinking" });
    return { ok: true, json: async () => ({ choices: [{ finish_reason: "stop", message: { content } }] }) };
  };
}
const body = (extra) => ({ session_id: "t", active_persona_id: "noah_g5_fractions", runtime_state: { understanding: 0.15 },
  win_moves: ["elicit", "extend", "revoice", "wait"], ...extra });

test("both tries repeat: the model's second line is kept, not the fixed template (ko and en)", async () => {
  for (const [locale, prev, a, b] of [
    ["ko", "8이 4보다 더 크니까 8분의 1이 더 커요.", "8이 4보다 더 크니까 8분의 1이 더 커요.", "음… 8이 4보다 더 크니까 8분의 1이 더 커요."],
    ["en", "Eight is bigger than four, so one eighth is bigger.", "Eight is bigger than four, so one eighth is bigger.", "Well, eight is bigger than four, so one eighth is bigger."],
  ]) {
    stub([a, b]);
    const out = await handleTurn(req(body({ locale, teacher_move: { input_mode: "menu", menu_tag: "extend", wait_time_ms: 3000 },
      move_history: [{ tag: "elicit" }], dialogue_tail: [{ speaker: "Noah", text: prev }] })), { OPENROUTER_API_KEY: "t" });
    assert.equal(out.student_utterance.text, b, locale);
  }
});

test("turn 1 and the scripted opening line are never treated as repetition", async () => {
  const opener = "8분의 1이랑 4분의 1 중에 뭐가 더 크냐고요? …8분의 1이요. 8이 4보다 크잖아요.";
  stub([opener]);   // restating the starting idea on the first turn
  let out = await handleTurn(req(body({ locale: "ko", teacher_move: { input_mode: "menu", menu_tag: "elicit", wait_time_ms: 3000 },
    move_history: [], scenario_context: { active_student: { opening_line: opener } }, dialogue_tail: [{ speaker: "도윤", text: opener }] })), { OPENROUTER_API_KEY: "t" });
  assert.equal(out.student_utterance.text, opener);
  stub([opener]);   // later turn: the opening line in the tail is not "the previous line"
  out = await handleTurn(req(body({ locale: "ko", teacher_move: { input_mode: "menu", menu_tag: "extend", wait_time_ms: 3000 },
    move_history: [{ tag: "elicit" }], scenario_context: { active_student: { opening_line: opener } }, dialogue_tail: [{ speaker: "도윤", text: opener }] })), { OPENROUTER_API_KEY: "t" });
  assert.equal(out.student_utterance.text, opener);
});

test("민호 may say the answer he already knows (no fractions leak filter for his persona); 도윤 may not", async () => {
  stub(["그림 보세요. 4분의 1이 더 커요."]);
  let out = await handleTurn(req(body({ locale: "ko", active_persona_id: "diego_ell", teacher_move: { input_mode: "menu", menu_tag: "elicit", wait_time_ms: 3000 } })), { OPENROUTER_API_KEY: "t" });
  assert.equal(out.student_utterance.text, "그림 보세요. 4분의 1이 더 커요.");
  stub(["아, 4분의 1이 더 커요.", "아, 4분의 1이 더 커요."]);
  out = await handleTurn(req(body({ locale: "ko", teacher_move: { input_mode: "menu", menu_tag: "elicit", wait_time_ms: 3000 } })), { OPENROUTER_API_KEY: "t" });
  assert.notEqual(out.student_utterance.text, "아, 4분의 1이 더 커요.");   // a leak stays a hard reject for 도윤
});
