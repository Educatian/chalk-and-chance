// Diagnostics carried in the /turn, /group_turn and /lecture_turn responses, so a re-check can
// see WHY a reply was a fixed line without access to Worker logs.
//
// diag.<part> = { source: "model" | "retry" | "fallback", attempts, rule, upstream_status,
//                 upstream_retries, repaired, rejected? }
//   source   model = first model reply used; retry = a later model reply used (after a soft
//            rejection, a parse error or an upstream retry); fallback = the fixed line.
//   rule     the rule or failure behind anything that is not a first-try model reply,
//            e.g. "leak:teacher_is_right", "english_mostly", "too_long", "upstream:429",
//            "parse_error", "repeat", "no_key".
//   rejected the model texts that were thrown away: ONLY when the request carries the
//            debug header and no learner session (see includeRejected); never by default.

export class UpstreamError extends Error {
  constructor(status, detail = "") {
    super(`upstream ${status} ${detail}`.trim());
    this.status = status;
  }
}

export const newDiag = () => ({ source: "model", attempts: 0, rule: null, upstream_status: null,
  upstream_retries: 0, repaired: null, rejected: [] });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
export const BACKOFF_MS = 400;

// One model call with ONE retry on 429 / 5xx / network failure (short backoff); upstream
// errors are recorded separately from content rejections.
export async function callWithUpstreamRetry(fn, d) {
  for (let i = 0; ; i++) {
    try {
      return await fn();
    } catch (e) {
      const status = e instanceof UpstreamError ? e.status : "network";
      d.upstream_status = status;
      const retryable = status === "network" || status === 429 || (typeof status === "number" && status >= 500);
      if (i === 0 && retryable) {
        d.upstream_retries += 1;
        await sleep(BACKOFF_MS);
        continue;
      }
      throw e;
    }
  }
}

// Rejected model texts only for a debug request: header x-cc-diag: 1 AND no learner session
// (no Authorization header). The release client sends neither the header nor (here) a session.
export function includeRejected(req) {
  const h = req && req.headers;
  if (!h || typeof h.get !== "function") return false;
  return h.get("x-cc-diag") === "1" && !h.get("authorization");
}

export function finishDiag(d, withTexts) {
  const out = { ...d };
  if (!withTexts || !out.rejected.length) delete out.rejected;
  return out;
}

// Cut a reply at a sentence boundary instead of rejecting it for length.
export function truncateAtSentence(t, maxChars, maxSentences) {
  const parts = String(t).match(/[^.!?…]+[.!?…]+["'”’]?\s*|[^.!?…]+$/g) || [String(t)];
  let out = "";
  let n = 0;
  for (const p of parts) {
    if (n >= maxSentences || (out + p).trim().length > maxChars) break;
    out += p;
    n += 1;
  }
  out = out.trim();
  if (!out) {   // a single sentence longer than the cap: cut at the last space
    const cut = String(t).slice(0, maxChars);
    out = (cut.lastIndexOf(" ") > maxChars * 0.5 ? cut.slice(0, cut.lastIndexOf(" ")) : cut).trim() + "…";
  }
  return out;
}
