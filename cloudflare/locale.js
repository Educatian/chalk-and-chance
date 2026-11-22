// Korean path for the LLM endpoints. The client sends `locale` ("ko" or "en") in every
// /turn, /group_turn and /lecture_turn body; anything else, or no field (older clients),
// stays English exactly as before.
import { PERSONAS_KO, STUDENT_KO_RULES, COACH_KO_RULES } from "./gamedata.js";

export const isKorean = (body) => String((body && body.locale) || "").toLowerCase().startsWith("ko");

// Same merge the game uses for data/i18n overlays: objects key by key, arrays by index,
// null keeps the English value.
export function mergeOverlay(base, over) {
  if (over === null || over === undefined) return base;
  if (Array.isArray(base) && Array.isArray(over)) return base.map((v, i) => (i < over.length ? mergeOverlay(v, over[i]) : v));
  if (base && over && typeof base === "object" && typeof over === "object" && !Array.isArray(base)) {
    const out = { ...base };
    for (const k of Object.keys(over)) out[k] = k in base ? mergeOverlay(base[k], over[k]) : over[k];
    return out;
  }
  return over;
}

export function personaFor(id, persona, ko) {
  return ko && PERSONAS_KO[id] ? mergeOverlay(persona, PERSONAS_KO[id]) : persona;
}

export const studentRulesKo = (name) => STUDENT_KO_RULES.split("[[KO_NAME]]").join(name || "학생");
export const MOVE_NAMES_KO = {
  elicit: "생각 묻기", extend: "더 묻기", revoice: "되말하기", tell: "설명하기",
  praise: "칭찬하기", connect: "삶과 잇기", redirect: "주의 돌리기", wait: "기다려 주기",
};
export const coachRulesKo = (tag) => COACH_KO_RULES.split("[[MOVE_KO]]").join(MOVE_NAMES_KO[tag] || "가르치는 수");

// Coach tips. Returns [ok, rule, hard, repairedText]: hard = empty or mostly English (fixed
// tip); style (학생, honorific endings) is soft (one retry, then the model's tip is kept);
// length is repaired by cutting at a sentence boundary. Naming other moves is fine: the
// coach prompt asks for the next step ("다음엔 기다려 주기").
import { truncateAtSentence } from "./diag.js";
export function validateCoach(tip, ko, tag) {
  let t = String(tip || "").trim();
  if (!t) return [false, "empty", true, null];
  const letters = (t.match(/[A-Za-z\uAC00-\uD7A3]/g) || []).length;
  if (ko && letters && (t.match(/[A-Za-z]/g) || []).length / letters > 0.5) return [false, "english_mostly", true, null];
  let fixed = null;
  if ((t.match(/[.!?…]+(\s|$)/g) || []).length > 2 || t.length > (ko ? 180 : 300)) {
    fixed = truncateAtSentence(t, ko ? 180 : 300, 2);
    t = fixed;
  }
  if (ko && t.includes("학생")) return [false, "voice:haksaeng", false, fixed];
  if (ko && /(주셨|하셨|드려요|드립니다|습니다)/.test(t)) return [false, "voice:honorific", false, fixed];
  return [true, "ok", false, fixed];
}
export const groupRulesKo = () => STUDENT_KO_RULES.split("Your name is [[KO_NAME]]. ").join("Use the speaker's name as given. ");
export const lectureRulesKo = () =>
  "\n# LANGUAGE: KOREAN\n- Write the reaction text and coach_tip in natural Korean 해요체 (class reactions may be short descriptions in Korean). " +
  "Students speak 존댓말 to the teacher. No translationese, no English words. Keep the JSON keys in English.";

// The resolution must not leak in Korean either.
// Giving in out loud: a leak for every persona.
export const LEAK_PATTERNS_KO = [
  /이제 알겠어/, /이제 이해했/, /제가 틀렸/, /선생님 말이 맞/, /그러니까 답은/,
];
// The fractions answer itself: a leak only for personas whose misconception IS the fractions
// (도윤), not for one who already knows it and struggles to say it (민호).
export const CONTENT_LEAK_PATTERNS_KO = [
  /4분의\s*1이 더 (커|크)/, /조각이 많을수록.*작/, /분모가 클수록.*작/,
];

export const CANNED_STUDENT_KO = {
  elicit: "음… 알겠어요. 제가 어떻게 생각했는지 말해 볼게요.",
  extend: "어… 그렇게 물어보시니까 제 처음 답이 맞는지 잘 모르겠어요.",
  revoice: "네… 제 말이 그거예요.",
  tell: "아… 네, 알겠어요.",
  praise: "…감사해요.",
  redirect: "네, 죄송해요.",
  wait_ok: "…아. 사실 제가 거꾸로 생각한 것 같기도 해요.",
  wait: "…",
  idea: (idea) => `제 생각은요, ${idea}`,
};

export const COACH_TIPS_KO = {
  elicit: "좋은 생각 묻기예요. 아이 생각에서 흔들리는 부분을 더 짚어 봐요.",
  extend: "잘 더 물었어요. 아이가 스스로 따져 보고 있어요.",
  revoice: "되말하기로 아이 생각이 모두에게 보이게 됐어요.",
  tell: "생각을 대신 해 줬어요. 참여가 떨어졌으니 먼저 생각을 물어봐요.",
  praise: "'잘했어'보다 무엇을 잘했는지 짚어 줘요.",
  redirect: "통하는 가장 작은 개입으로 주의를 돌려요.",
  wait: "3~5초 기다려 줘요. 침묵은 아이가 채우게 둬요.",
};

// Free-text moves typed in Korean (the LLM classifier handles both languages; this is the
// no-key fallback).
export function heuristicClassifyKo(text) {
  const t = String(text || "").trim();
  if (!t) return "wait";
  if (/(어떻게|왜 그렇게|어떻게 알|설명해 줄래|보여 줄래|무슨 뜻)/.test(t)) return "elicit";
  if (/(그럼|만약|그러면).*(\?|까)/.test(t)) return "extend";
  if (/^(그러니까 네 말은|네 말은|.*라는 거구나|.*라는 거지)/.test(t)) return "revoice";
  if (/(잘했어|좋아|훌륭|멋지)/.test(t)) return "praise";
  if (/(집중|조용|자리에|그만|여기 봐)/.test(t)) return "redirect";
  if (/(좋아하는|학교 밖|집에서|잘하는 거)/.test(t)) return "connect";
  if (/(정답은|사실은|이렇게 하는 거야|왜냐하면)/.test(t)) return "tell";
  return null;
}
