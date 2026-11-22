// Durable server log: one append-only D1 row per API request (table server_log, migration
// cloudflare/migrations/0001_server_log.sql), plus a verified archive to R2 (off by default).
//
// What a row holds: time (UTC, ms), route, method, HTTP status, latency, Worker version,
// the identifiers this API already uses (learner user_id from a VERIFIED JWT, the demo
// anon_id the client sends to /telemetry_anon, the client session_id), locale, persona, move,
// input mode, the LENGTH of teacher-typed text (never the text), the full diag object
// including rejected model texts, upstream status, a scrubbed error, and coarse location
// (country, Cloudflare colo) as telemetry already stores.
// Never stored: request bodies, passwords/passcodes, tokens, Authorization / X-Voice-Token
// headers, raw IPs, typed text. Bodies of /auth/login and /voice_token are never read.
// A log write never affects the response: it runs in ctx.waitUntil and every error is swallowed.

import { REJECTED } from "./diag.js";

const LLM_ROUTES = new Set(["/turn", "/group_turn", "/lecture_turn"]);
const NO_BODY = new Set(["/auth/login", "/voice_token"]);   // credentials: never parsed here
const s = (v, n = 96) => (v === undefined || v === null || v === "" ? null : String(v).slice(0, n));

// Read a few allow-listed fields from a CLONE of the body. Must be called before the route
// handler consumes the body; the clone is taken synchronously.
export function peekBody(req, path) {
  if (req.method !== "POST" || NO_BODY.has(path)) return Promise.resolve({});
  let copy;
  try { copy = req.clone(); } catch (_e) { return Promise.resolve({}); }
  return copy.json().then((b) => {
    if (!b || typeof b !== "object") return {};
    if (LLM_ROUTES.has(path)) {
      const m = b.teacher_move || {};
      return { session_id: s(b.session_id), locale: s(b.locale, 8), persona: s(b.active_persona_id, 64),
        move: s(m.menu_tag, 32), input_mode: s(m.input_mode, 16),
        text_len: typeof m.text === "string" ? m.text.length : null };
    }
    if (path === "/tts") return { persona: s(b.persona_id, 64) };
    if (path === "/telemetry" || path === "/telemetry_anon") {
      const ev = Array.isArray(b.events) ? b.events : [];
      return { anon_id: path === "/telemetry_anon" ? s(b.anon_id, 64) : null,
        session_id: s(ev[0] && ev[0].session_id) };
    }
    return {};
  }).catch(() => ({}));
}

// diag with the rejected texts put back (they travel under a Symbol key, see diag.js).
function fullDiag(diag) {
  if (!diag || typeof diag !== "object") return null;
  const out = {};
  for (const [k, part] of Object.entries(diag)) {
    out[k] = part && part[REJECTED] ? { ...part, rejected: part[REJECTED] } : part;
  }
  return out;
}
function firstUpstream(diag) {
  for (const part of Object.values(diag || {})) {
    if (part && part.upstream_status !== null && part.upstream_status !== undefined) return String(part.upstream_status);
  }
  return null;
}

// Every string value of env (secrets, passcodes, keys) plus the fixed default passcodes and
// anything token-shaped is removed from every text column before the row is written.
const DEFAULT_PASSCODES = ["CAT5312026", "CAT1002026"];
export function scrubber(env, req) {
  const secrets = [...DEFAULT_PASSCODES];
  for (const v of Object.values(env || {})) if (typeof v === "string" && v.trim().length >= 6) secrets.push(v.trim());
  for (const h of ["Authorization", "X-Voice-Token"]) {
    const v = (req.headers.get(h) || "").replace(/^Bearer\s+/i, "").trim();
    if (v.length >= 6) secrets.push(v);
  }
  return (t) => {
    if (t === null || t === undefined) return t;
    let out = String(t);
    for (const x of secrets) out = out.split(x).join("[redacted]");
    return out
      .replace(/Bearer\s+\S+/gi, "Bearer [redacted]")
      .replace(/[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}(\.[A-Za-z0-9_-]{16,})?/g, "[redacted-token]");
  };
}

export function buildRow({ req, env, path, status, latencyMs, info = {}, peek = {}, userId = null, now = new Date() }) {
  const clean = scrubber(env, req);
  const cf = req.cf || {};
  const diag = fullDiag(info.diag);
  // On /auth/login and /voice_token a JSON parse error can quote the body: keep only its name.
  const e = info.error;
  const err = !e ? info.note || null
    : NO_BODY.has(path) ? e.name || "Error" : `${e.name || "Error"}: ${String(e.message || e)}`;
  return {
    ts: now.toISOString(), route: path.slice(0, 64), method: req.method, status, latency_ms: latencyMs,
    worker_version: (env.CF_VERSION_METADATA && env.CF_VERSION_METADATA.id) || null,
    user_id: userId, anon_id: clean(peek.anon_id || null), session_id: clean(peek.session_id || null),
    locale: peek.locale || null, persona: peek.persona || null, move: peek.move || null,
    input_mode: peek.input_mode || null, text_len: peek.text_len ?? null,
    diag: diag ? clean(JSON.stringify(diag)).slice(0, 16000) : null,
    upstream_status: firstUpstream(info.diag),
    error: err ? clean(err).slice(0, 300) : null,
    country: cf.country || null, colo: cf.colo || null,
  };
}

const COLS = ["ts", "route", "method", "status", "latency_ms", "worker_version", "user_id", "anon_id", "session_id",
  "locale", "persona", "move", "input_mode", "text_len", "diag", "upstream_status", "error", "country", "colo"];
const INSERT = `INSERT INTO server_log (${COLS.join(",")}) VALUES (${COLS.map(() => "?").join(",")})`;

export async function writeServerLog(env, row) {
  await env.DB.prepare(INSERT).bind(...COLS.map((c) => row[c] ?? null)).run();
}

// ---------------------------------------------------------------------------------------
// Archive to R2 (scheduled). OFF unless the bucket is bound as LOG_BUCKET AND env.LOG_ARCHIVE
// is "on". Rows are archived in id order, in chunks of CHUNK rows, as gzipped NDJSON:
//   server_log/<YYYY-MM of the first row>/<first_id>-<last_id>.ndjson.gz
// Each object is read back, decompressed and checked (row count + sha256) before the cursor in
// server_log/manifest.json moves. D1 rows are deleted ONLY when they are at or below that
// verified cursor AND older than LOG_KEEP_MONTHS (default 12). Rows newer than one hour are
// never archived in a run, so in-flight writes are not skipped.
export const CHUNK = 10000;
const MANIFEST = "server_log/manifest.json";

async function sha256Hex(text) {
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(h)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
async function gzip(text) {
  return new Response(new Blob([text]).stream().pipeThrough(new CompressionStream("gzip"))).arrayBuffer();
}
async function gunzip(buf) {
  return new Response(new Blob([buf]).stream().pipeThrough(new DecompressionStream("gzip"))).text();
}

export async function archiveServerLog(env, now = new Date(), maxChunks = 50) {
  if (!env.LOG_BUCKET || String(env.LOG_ARCHIVE || "").trim() !== "on") return { skipped: "off" };
  const bucket = env.LOG_BUCKET;
  const mObj = await bucket.get(MANIFEST);
  const manifest = mObj ? JSON.parse(await mObj.text()) : { cursor: 0, objects: [] };
  const settled = new Date(now.getTime() - 3600 * 1000).toISOString();
  const written = [];
  for (let i = 0; i < maxChunks; i++) {
    const { results } = await env.DB.prepare(
      `SELECT * FROM server_log WHERE id > ? AND ts < ? ORDER BY id LIMIT ${CHUNK}`).bind(manifest.cursor, settled).all();
    if (!results || !results.length) break;
    const text = results.map((r) => JSON.stringify(r)).join("\n") + "\n";
    const first = results[0], last = results[results.length - 1];
    const key = `server_log/${first.ts.slice(0, 7)}/${first.id}-${last.id}.ndjson.gz`;
    const sha = await sha256Hex(text);
    await bucket.put(key, await gzip(text), { customMetadata: { rows: String(results.length), sha256: sha } });
    // verify the stored object before moving the cursor
    const back = await bucket.get(key);
    const check = back ? await gunzip(await back.arrayBuffer()) : "";
    if (!back || (await sha256Hex(check)) !== sha || check.split("\n").length - 1 !== results.length) {
      throw new Error(`archive verify failed for ${key}`);
    }
    manifest.objects.push({ key, rows: results.length, sha256: sha, first_id: first.id, last_id: last.id,
      first_ts: first.ts, last_ts: last.ts });
    manifest.cursor = last.id;
    await bucket.put(MANIFEST, JSON.stringify(manifest, null, 1));
    written.push(key);
  }
  const keepMonths = Number(env.LOG_KEEP_MONTHS || 12);
  const cutoff = new Date(now);
  cutoff.setUTCMonth(cutoff.getUTCMonth() - keepMonths);
  const pruned = manifest.cursor > 0
    ? await env.DB.prepare("DELETE FROM server_log WHERE id <= ? AND ts < ?").bind(manifest.cursor, cutoff.toISOString()).run()
    : null;
  return { written, cursor: manifest.cursor, pruned: pruned && pruned.meta ? pruned.meta.changes : 0 };
}
