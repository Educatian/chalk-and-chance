// Korean path for the LLM endpoints, against a local stub (no network, no hosted Worker).
// Run: node --test cloudflare/test/
import { test } from "node:test";
import assert from "node:assert/strict";
import { handleTurn } from "../turn.js";
import { handleGroupTurn } from "../group.js";
import { handleLectureTurn } from "../lecture.js";
import { heuristicClassifyKo, isKorean } from "../locale.js";

const HANGUL = /[가-힣]/;
const req = (body) => ({ json: async () => body });
const turnBody = (extra = {}) => ({
  session_id: "t", scenario_id: "discussion_fractions", active_persona_id: "noah_g5_fractions",
  runtime_state: { understanding: 0.15, trust_in_teacher: 0.5, engagement: 0.4, misconception_resolved: false, turns_elapsed: 1 },
  teacher_move: { input_mode: "menu", menu_tag: "elicit", wait_time_ms: 3000 }, win_moves: ["elicit", "extend", "revoice", "wait"],
  dialogue_tail: [], move_history: [], ...extra,
});

// Stub OpenRouter: records every request; refuses any other host so a test can never reach the network.
function stubFetch(replies) {
  const calls = [];
  globalThis.fetch = async (url, init) => {
    if (!String(url).startsWith("https://openrouter.ai/")) throw new Error("unexpected host " + url);
    const body = JSON.parse(init.body);
    calls.push(body);
    const sys = body.messages[0].content;
    let content;
    if (sys.includes("You label a teacher's utterance")) content = '{"tag":"elicit"}';
    else if (sys.includes("coach_tip")) content = JSON.stringify({ coach_tip: replies.coach || "Coach note." });
    else content = JSON.stringify({ text: replies.student.shift() ?? "...", emotion_shown: "thinking" });
    return { ok: true, json: async () => ({ choices: [{ message: { content } }] }) };
  };
  return calls;
}

test("locale field: ko only for ko*", () => {
  assert.equal(isKorean({ locale: "ko" }), true);
  assert.equal(isKorean({ locale: "ko_KR" }), true);
  assert.equal(isKorean({ locale: "en" }), false);
  assert.equal(isKorean({}), false);
});

test("no API key, ko: Korean student (Korean name) and Korean coach", async () => {
  const out = await handleTurn(req(turnBody({ locale: "ko" })), {});
  assert.match(out.student_utterance.text, HANGUL);
  assert.equal(out.student_utterance.speaker, "도윤");
  assert.match(out.coach_tip, HANGUL);
});

test("no API key, no locale (older client): English as before", async () => {
  const out = await handleTurn(req(turnBody()), {});
  assert.equal(out.student_utterance.speaker, "Noah");
  assert.doesNotMatch(out.student_utterance.text + out.coach_tip, HANGUL);
});

test("ko: prompt carries the Korean rules and the Korean persona; reply passes through", async () => {
  const calls = stubFetch({ student: ["음… 8분의 1이 더 큰 것 같아요. 8이 더 크잖아요."], coach: "생각을 잘 물었어요." });
  const out = await handleTurn(req(turnBody({ locale: "ko" })), { OPENROUTER_API_KEY: "test" });
  const sys = calls.map((c) => c.messages[0].content).find((s) => s.includes("[[") === false && s.includes("LANGUAGE: KOREAN") && s.includes("도윤"));
  assert.ok(sys, "student prompt has the Korean rules and the Korean name");
  assert.ok(calls.some((c) => c.messages[0].content.includes("coach_tip") && c.messages[0].content.includes("되말하기")), "coach prompt has the Korean move names");
  assert.equal(out.student_utterance.text, "음… 8분의 1이 더 큰 것 같아요. 8이 더 크잖아요.");
  assert.equal(out.coach_tip, "생각을 잘 물었어요.");
});

test("en: no Korean rules in any prompt", async () => {
  const calls = stubFetch({ student: ["Um, one eighth, because eight is bigger."] });
  await handleTurn(req(turnBody({ locale: "en" })), { OPENROUTER_API_KEY: "test" });
  assert.ok(calls.length >= 2);
  assert.ok(calls.every((c) => !c.messages[0].content.includes("LANGUAGE: KOREAN")));
});

test("ko: an English reply is rejected twice, then the Korean fallback is used", async () => {
  stubFetch({ student: ["One eighth is bigger.", "Eight is more than four."] });
  const out = await handleTurn(req(turnBody({ locale: "ko" })), { OPENROUTER_API_KEY: "test" });
  assert.match(out.student_utterance.text, HANGUL);
  assert.doesNotMatch(out.student_utterance.text, /[A-Za-z]{3,}/);
});

test("ko: a reply that gives away the answer is rejected", async () => {
  stubFetch({ student: ["아, 이제 알겠어요. 4분의 1이 더 커요.", "음… 잘 모르겠어요."] });
  const out = await handleTurn(req(turnBody({ locale: "ko" })), { OPENROUTER_API_KEY: "test" });
  assert.equal(out.student_utterance.text, "음… 잘 모르겠어요.");
});

test("ko free text without a key: Korean heuristic classifier", async () => {
  assert.equal(heuristicClassifyKo("어떻게 그렇게 생각했어?"), "elicit");
  assert.equal(heuristicClassifyKo("다들 여기 봐"), "redirect");
  const out = await handleTurn(req(turnBody({ locale: "ko", teacher_move: { input_mode: "free_text", text: "왜 그렇게 생각했는지 설명해 줄래?", wait_time_ms: 3000 } })), {});
  assert.equal(out.judge.classified_tag, "elicit");
});

test("group and lecture prompts get the Korean rules only for ko", async () => {
  for (const ko of [true, false]) {
    const calls = stubFetch({ student: [] });
    const grp = { members: [{ name: "예린", talkativeness: 0.8 }], teacher_move: { menu_tag: "probe" }, group_state: {}, ...(ko ? { locale: "ko" } : {}) };
    await handleGroupTurn(req(grp), { OPENROUTER_API_KEY: "test" });
    const lec = { teacher_move: { menu_tag: "ask" }, class_state: {}, scenario_context: {}, ...(ko ? { locale: "ko" } : {}) };
    await handleLectureTurn(req(lec), { OPENROUTER_API_KEY: "test" });
    const prompts = calls.map((c) => c.messages[0].content);
    assert.equal(prompts.length, 2);
    for (const p of prompts) assert.equal(p.includes("LANGUAGE: KOREAN"), ko);
  }
});
