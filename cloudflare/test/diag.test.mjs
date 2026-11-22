// diag on every response, rule kinds (hard / soft / repair), upstream retry, and rejected texts
// only for a debug request without a learner session. Local stub; no network.
// Run: node --test cloudflare/test/diag.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { handleTurn } from "../turn.js";
import { handleGroupTurn } from "../group.js";
import { handleLectureTurn } from "../lecture.js";

const req = (body, headers = {}) => ({ json: async () => body, headers: new Headers(headers) });
const KEY = { OPENROUTER_API_KEY: "t" };
const turn = (extra = {}) => ({ session_id: "t", active_persona_id: "noah_g5_fractions", locale: "ko",
  runtime_state: { understanding: 0.15 }, win_moves: ["elicit", "extend", "revoice", "wait"],
  teacher_move: { input_mode: "menu", menu_tag: "extend", wait_time_ms: 3000 },
  move_history: [{ tag: "elicit" }], dialogue_tail: [], ...extra });

// students: a queue of replies ({status} = an upstream error, a string = model content);
// the coach always answers well.
function stub(students, coach = '{"coach_tip":"더 묻기로 아이가 스스로 따져 보게 했어요."}') {
  globalThis.fetch = async (url, init) => {
    const sys = JSON.parse(init.body).messages[0].content;
    let next = sys.includes("coach_tip") ? coach : students.shift();
    if (next === undefined) next = '{"text":"…","emotion_shown":"thinking"}';
    if (typeof next === "object") return { ok: false, status: next.status, text: async () => "err" };
    return { ok: true, status: 200, json: async () => ({ choices: [{ finish_reason: "stop", message: { content: next } }] }) };
  };
}
const say = (t) => JSON.stringify({ text: t, emotion_shown: "thinking" });

test("first-try model reply: diag says model, 1 attempt, no texts", async () => {
  stub([say("음… 8분의 1이 더 커요. 8이 더 크잖아요.")]);
  const out = await handleTurn(req(turn()), KEY);
  assert.deepEqual([out.diag.student.source, out.diag.student.attempts, out.diag.student.rule], ["model", 1, null]);
  assert.equal(out.diag.coach.source, "model");
  assert.equal("rejected" in out.diag.student, false);
});

test("'선생님 말이 맞…' after an extend is soft: one retry, then the model's line is kept", async () => {
  const line = "음… 선생님 말이 맞는 것 같기도 해요. 근데 8이 더 크잖아요.";
  stub([say(line), say(line)]);
  const out = await handleTurn(req(turn()), KEY);
  assert.equal(out.student_utterance.text, line);
  assert.deepEqual([out.diag.student.source, out.diag.student.rule, out.diag.student.attempts], ["retry", "leak:teacher_is_right", 2]);
});

test("민호's Spanish word is fine; a mostly-English reply in Korean mode is a hard fallback", async () => {
  stub([say("음… 우리 이모 트럭에서 pizza를 여덟 조각으로 잘라요. 그거랑 같아요?")]);
  let out = await handleTurn(req(turn({ active_persona_id: "diego_ell" })), KEY);
  assert.equal(out.diag.student.source, "model");
  stub([say("I think one eighth is bigger because eight is bigger."), say("Eight is bigger so one eighth is bigger.")]);
  out = await handleTurn(req(turn()), KEY);
  assert.deepEqual([out.diag.student.source, out.diag.student.rule], ["fallback", "english_mostly"]);
});

test("too long is repaired at a sentence boundary, not rejected", async () => {
  const long = "8분의 1이 더 커요. 8이 4보다 크니까요. 그리고 조각이 많으면 더 많이 먹을 수 있잖아요. 그래서 저는 8분의 1이 좋아요. 진짜예요.";
  stub([say(long)]);
  const out = await handleTurn(req(turn()), KEY);
  assert.equal(out.diag.student.source, "model");
  assert.equal(out.diag.student.repaired, "too_long");
  assert.equal(out.student_utterance.text, "8분의 1이 더 커요. 8이 4보다 크니까요. 그리고 조각이 많으면 더 많이 먹을 수 있잖아요.");
});

test("the answer handed over by 도윤 (whose misconception it is) is hard; 민호 may say it", async () => {
  stub([say("아, 4분의 1이 더 커요."), say("4분의 1이 더 크네요.")]);
  let out = await handleTurn(req(turn()), KEY);
  assert.deepEqual([out.diag.student.source, out.diag.student.rule], ["fallback", "leak:content_answer"]);
  stub([say("그림 보세요. 4분의 1이 더 커요.")]);
  out = await handleTurn(req(turn({ active_persona_id: "diego_ell" })), KEY);
  assert.equal(out.diag.student.source, "model");
});

test("upstream 429: one retry after a short backoff; twice -> fallback with upstream:429", async () => {
  stub([{ status: 429 }, say("음… 8분의 1이 더 커요.")]);
  let out = await handleTurn(req(turn()), KEY);
  assert.deepEqual([out.diag.student.source, out.diag.student.upstream_status, out.diag.student.upstream_retries], ["retry", 429, 1]);
  stub([{ status: 503 }, { status: 503 }]);
  out = await handleTurn(req(turn()), KEY);
  assert.deepEqual([out.diag.student.source, out.diag.student.rule], ["fallback", "upstream:503"]);
});

test("unparseable output is a parse_error, then the retry is used", async () => {
  stub(['{"text": "음… 8분의', say("8분의 1이 더 커요.")]);
  const out = await handleTurn(req(turn()), KEY);
  assert.deepEqual([out.diag.student.source, out.diag.student.rule], ["retry", "parse_error"]);
});

test("rejected texts only with x-cc-diag: 1 and no learner session", async () => {
  const bad = "I think one eighth is bigger.";
  for (const [headers, expect] of [[{ "x-cc-diag": "1" }, true], [{ "x-cc-diag": "1", authorization: "Bearer x" }, false], [{}, false]]) {
    stub([say(bad), say(bad)]);
    const out = await handleTurn(req(turn(), headers), KEY);
    assert.equal(Array.isArray(out.diag.student.rejected), expect, JSON.stringify(headers));
    if (expect) assert.deepEqual(out.diag.student.rejected, [bad, bad]);
  }
});

test("/group_turn and /lecture_turn carry diag too", async () => {
  stub(['{"speaker":"예린","text":"우리는 8분의 1이 크다고 생각해요.","emotion_shown":"thinking"}']);
  const g = await handleGroupTurn(req({ members: [{ name: "예린" }], teacher_move: { menu_tag: "probe" }, group_state: {}, locale: "ko" }), KEY);
  assert.equal(g.diag.utterance.source, "model");
  const lq = [{ status: 500 }, '{"reaction":{"speaker":"Class","text":"Most students track it.","scope":"class"},"coach_tip":"Check."}'];
  globalThis.fetch = async () => { const x = lq.shift(); return typeof x === "object"
    ? { ok: false, status: x.status, text: async () => "err" }
    : { ok: true, status: 200, json: async () => ({ choices: [{ message: { content: x } }] }) }; };
  const l = await handleLectureTurn(req({ teacher_move: { menu_tag: "present" }, class_state: {}, scenario_context: {} }), KEY);
  assert.deepEqual([l.diag.reaction.source, l.diag.reaction.upstream_status], ["retry", 500]);
  const n = await handleLectureTurn(req({ teacher_move: { menu_tag: "present" }, class_state: {}, scenario_context: {} }), {});
  assert.deepEqual([n.diag.reaction.source, n.diag.reaction.rule], ["fallback", "no_key"]);
});
