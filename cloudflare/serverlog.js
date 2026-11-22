// Durable server log: one append-only D1 row per API request (table server_log, migration
// cloudflare/migrations/0001_server_log.sql), plus a verified archive to R2 (off by default).
//
// What a row holds: time (UTC, ms), route, method, HTTP status, latency, Worker version,
// the identifiers this API already uses (learner user_id from a VERIFIED JWT, the demo
// anon_id the client sends to /telemetry_anon and the LLM routes, the client session_id), locale, persona, move,
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
// anon_id normalised exactly as /telemetry_anon stores it (worker.js slug), so rows join.
const anon = (v) => s(String(v || "").trim().toLowerCase().replace(/\s+/g, "_").slice(0, 40));

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
      return { session_id: s(b.session_id), anon_id: anon(b.anon_id), locale: s(b.locale, 8), persona: s(b.active_persona_id, 64),
        move: s(m.menu_tag, 32), input_mode: s(m.input_mode, 16),
        text_len: typeof m.text === "string" ? m.text.length : null };
    }
    if (path === "/tts") return { persona: s(b.persona_id, 64) };
    if (path === "/telemetry" || path === "/telemetry_anon") {
      const ev = Array.isArray(b.events) ? b.events : [];
      return { anon_id: path === "/telemetry_anon" ? anon(b.anon_id) || "unknown" : null,
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
  for (const h of ["Authorization", "X-Voice-Token", "X-Admin-Token"]) {
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

// Write one chunk as gzipped NDJSON and verify it by reading it back (sha256 + row count).
async function putVerified(bucket, key, rows) {
  const text = rows.map((r) => JSON.stringify(r)).join("\n") + "\n";
  const sha = await sha256Hex(text);
  const body = await gzip(text);
  await bucket.put(key, body, { customMetadata: { rows: String(rows.length), sha256: sha } });
  const back = await bucket.get(key);
  const check = back ? await gunzip(await back.arrayBuffer()) : "";
  if (!back || (await sha256Hex(check)) !== sha || check.split("\n").length - 1 !== rows.length) {
    throw new Error(`archive verify failed for ${key}`);
  }
  const first = rows[0], last = rows[rows.length - 1];
  return { key, rows: rows.length, sha256: sha, bytes: body.byteLength, first_id: first.id, last_id: last.id,
    first_ts: first.ts, last_ts: last.ts };
}
async function readManifest(bucket) {
  const m = await bucket.get(MANIFEST);
  return m ? JSON.parse(await m.text()) : { cursor: 0, objects: [] };
}
function pruneCutoff(env, now) {
  const cutoff = new Date(now);
  cutoff.setUTCMonth(cutoff.getUTCMonth() - Number(env.LOG_KEEP_MONTHS || 12));
  return cutoff.toISOString();
}

// Rows eligible for archiving: id above the cursor and below the first row that is still
// "fresh" (ts within the last hour). Cutting on id, not on ts, means the cursor can never pass
// a row that was skipped (a slow request can have a lower id than an earlier-started one).
const ELIGIBLE = `id > ? AND id < COALESCE((SELECT MIN(id) FROM server_log WHERE ts >= ?), 9007199254740991)`;
const settledTs = (now) => new Date(now.getTime() - 3600 * 1000).toISOString();
const keyFor = (first, last) => `server_log/${first.ts.slice(0, 7)}/${first.id}-${last.id}.ndjson.gz`;
async function countRows(env, where, ...args) {
  return Number(((await env.DB.prepare(`SELECT COUNT(*) n FROM server_log WHERE ${where}`).bind(...args).first()) || {}).n || 0);
}

// The archive job. prune=false (on-demand runs) archives and verifies but deletes nothing.
export async function archiveServerLog(env, now = new Date(), maxChunks = 50, { prune = true } = {}) {
  if (!env.LOG_BUCKET || String(env.LOG_ARCHIVE || "").trim() !== "on") return { skipped: "off" };
  const bucket = env.LOG_BUCKET;
  const manifest = await readManifest(bucket);
  const cursorBefore = manifest.cursor;
  const settled = settledTs(now);
  const objects = [];
  for (let i = 0; i < maxChunks; i++) {
    const { results } = await env.DB.prepare(`SELECT * FROM server_log WHERE ${ELIGIBLE} ORDER BY id LIMIT ${CHUNK}`)
      .bind(manifest.cursor, settled).all();
    if (!results || !results.length) break;
    const entry = await putVerified(bucket, keyFor(results[0], results[results.length - 1]), results);
    const { bytes, ...forManifest } = entry;
    manifest.objects.push(forManifest);
    manifest.cursor = entry.last_id;
    await bucket.put(MANIFEST, JSON.stringify(manifest, null, 1));
    objects.push(entry);
  }
  const cutoff = pruneCutoff(env, now);
  const wouldPrune = await countRows(env, "id <= ? AND ts < ?", manifest.cursor, cutoff);
  let pruned = 0;
  if (prune && wouldPrune > 0) {
    const r = await env.DB.prepare("DELETE FROM server_log WHERE id <= ? AND ts < ?").bind(manifest.cursor, cutoff).run();
    pruned = r && r.meta ? r.meta.changes : 0;
  }
  return { written: objects.map((o) => o.key), objects, cursor_before: cursorBefore, cursor: manifest.cursor,
    prune_cutoff: cutoff, would_prune_rows: wouldPrune, pruned };
}

// What a run would write now, without writing anything anywhere.
export async function archiveDryRun(env, now = new Date(), maxChunks = 50) {
  if (!env.LOG_BUCKET) return { dry_run: true, error: "LOG_BUCKET is not bound" };
  const manifest = await readManifest(env.LOG_BUCKET);
  const settled = settledTs(now);
  const { results } = await env.DB.prepare(`SELECT id, ts FROM server_log WHERE ${ELIGIBLE} ORDER BY id LIMIT ${CHUNK * maxChunks}`)
    .bind(manifest.cursor, settled).all();
  const ids = results || [];
  const would_write = [];
  for (let i = 0; i < ids.length; i += CHUNK) {
    const part = ids.slice(i, i + CHUNK);
    would_write.push({ key: keyFor(part[0], part[part.length - 1]), rows: part.length,
      first_id: part[0].id, last_id: part[part.length - 1].id });
  }
  const cutoff = pruneCutoff(env, now);
  return { dry_run: true, archive_enabled: String(env.LOG_ARCHIVE || "").trim() === "on", cursor: manifest.cursor,
    archived_objects: manifest.objects.length, would_write,
    not_yet_eligible_rows: await countRows(env, "id > ? AND ts >= ?", manifest.cursor, settled),
    prune_cutoff: cutoff,
    would_prune_rows: await countRows(env, "id <= ? AND ts < ?", manifest.cursor, cutoff) };
}

// On-demand real run for verification: archive + verify, never prune, and check the outcome.
export async function archiveOnDemand(env, now = new Date()) {
  const out = await archiveServerLog(env, now, 50, { prune: false });
  if (out.skipped) return out;
  const archived = out.objects.reduce((n, o) => n + o.rows, 0);
  const stillInD1 = await countRows(env, "id > ? AND id <= ?", out.cursor_before, out.cursor);
  const checks = {
    objects_written: out.objects.length > 0,
    read_back_verified: out.objects.every((o) => o.sha256 && o.rows > 0),   // putVerified throws otherwise
    manifest_cursor_moved: out.cursor > out.cursor_before,
    archived_rows_still_in_d1: stillInD1 === archived,
    nothing_pruned: out.pruned === 0,
  };
  return { mode: "run", ...out, manifest_key: MANIFEST, archived_rows: archived, d1_rows_in_archived_range: stillInD1,
    checks, pass: Object.values(checks).every(Boolean) };
}
