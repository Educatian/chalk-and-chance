// Chalk & Chance auth + ECD data API — one Cloudflare Worker over D1.
// Does everything the Supabase plan would: named-account login (class code + name +
// password), JWT issuance, per-learner telemetry + competency upload. No Supabase.
//
// Bindings (wrangler.toml): DB (D1), and secret WORKER_SECRET (JWT signing key).
// Routes:
//   POST /auth/login   {class_code,name,password}  -> {token,user_id,display_name,role}
//                       (first login in an open class self-enrolls and sets the password)
//   GET  /me           (Bearer)                     -> profile
//   POST /telemetry    (Bearer) {events:[...]}      -> stores each event line
//   POST /competency   (Bearer) {skills:[{skill,theta,prob,n}]} -> upsert

import { handleTurn } from "./turn.js";
import { handleTts } from "./tts.js";
import { handleGroupTurn } from "./group.js";
import { handleLectureTurn } from "./lecture.js";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Voice-Token",
};
const json = (o, status = 200) =>
  new Response(JSON.stringify(o), { status, headers: { "Content-Type": "application/json", ...CORS } });

const enc = new TextEncoder();
const b64url = (buf) =>
  btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const b64urlToBytes = (s) => {
  s = s.replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(atob(s + "===".slice((s.length + 3) % 4)), (c) => c.charCodeAt(0));
};

// --- password hashing (PBKDF2-SHA256) ---------------------------------------
async function hashPw(password, saltB64) {
  const salt = saltB64 ? b64urlToBytes(saltB64) : crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey("raw", enc.encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt, iterations: 100000, hash: "SHA-256" }, key, 256);
  return { hash: b64url(bits), salt: b64url(salt) };
}

// --- JWT (HS256) ------------------------------------------------------------
async function hmacKey(secret) {
  return crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"]);
}
async function signJWT(payload, secret) {
  const head = b64url(enc.encode(JSON.stringify({ alg: "HS256", typ: "JWT" })));
  const body = b64url(enc.encode(JSON.stringify(payload)));
  const data = `${head}.${body}`;
  const sig = await crypto.subtle.sign("HMAC", await hmacKey(secret), enc.encode(data));
  return `${data}.${b64url(sig)}`;
}

async function signVoiceToken(payload, secret) {
  const body = b64url(enc.encode(JSON.stringify(payload)));
  const sig = await crypto.subtle.sign("HMAC", await hmacKey(secret), enc.encode(body));
  return `${body}.${b64url(sig)}`;
}
async function verifyJWT(token, secret) {
  const [h, b, s] = (token || "").split(".");
  if (!h || !b || !s) return null;
  const ok = await crypto.subtle.verify("HMAC", await hmacKey(secret), b64urlToBytes(s), enc.encode(`${h}.${b}`));
  if (!ok) return null;
  const payload = JSON.parse(new TextDecoder().decode(b64urlToBytes(b)));
  if (payload.exp && Date.now() / 1000 > payload.exp) return null;
  return payload;
}
function bearer(req) {
  const a = req.headers.get("Authorization") || "";
  return a.startsWith("Bearer ") ? a.slice(7) : "";
}
const uuid = () => crypto.randomUUID();
const clientIp = (req) => req.headers.get("CF-Connecting-IP") || "anon";

// Per-IP rate limit on the paid endpoints (OpenRouter + ElevenLabs cost guard).
// Checks a per-minute burst cap and a per-hour sustained cap in D1. Returns false when
// over limit; the game degrades gracefully (LLM->stub, TTS->silent) on the 429.
async function rateLimit(env, ip, bucket) {
  const windows = [[40, 60], [300, 3600]];   // [limit, seconds]
  const now = Math.floor(Date.now() / 1000);
  for (const [limit, win] of windows) {
    const k = `${bucket}:${ip}:${win}:${Math.floor(now / win)}`;
    const row = await env.DB.prepare(
      "INSERT INTO rate_limits(k,n,exp) VALUES(?,1,?) ON CONFLICT(k) DO UPDATE SET n=n+1 RETURNING n")
      .bind(k, now + win).first();
    if (row && row.n > limit) return false;
  }
  if (Math.random() < 0.02) {
    await env.DB.prepare("DELETE FROM rate_limits WHERE exp < ?").bind(now).run();
  }
  return true;
}
const slug = (s) => (s || "").trim().toLowerCase().replace(/\s+/g, "_").slice(0, 40);
const TELEMETRY_STRING_FIELDS = [
  "event", "session_id", "construct_id", "scenario_id", "mode", "scope", "tag", "source",
  "item_id", "result", "reason", "rank", "badge", "profile", "persona_id", "emotion_shown",
];
const TELEMETRY_NUMBER_FIELDS = [
  "turn", "score", "theta", "prob", "n", "progress", "comprehension", "attention",
  "composure", "order", "understanding", "participation", "wait_ms", "remaining",
];
const TELEMETRY_BOOL_FIELDS = ["won", "targets", "wait_ok", "ok", "resolved", "level_up"];

function copyStrings(src, keys, maxLen = 96) {
  const out = {};
  for (const key of keys) {
    if (src[key] !== undefined && src[key] !== null) out[key] = String(src[key]).slice(0, maxLen);
  }
  return out;
}

function copyNumbers(src, keys) {
  const out = {};
  for (const key of keys) {
    if (src[key] !== undefined && src[key] !== null && Number.isFinite(Number(src[key]))) out[key] = Number(src[key]);
  }
  return out;
}

function copyBools(src, keys) {
  const out = {};
  for (const key of keys) {
    if (src[key] !== undefined && src[key] !== null) out[key] = Boolean(src[key]);
  }
  return out;
}

function safeNumberMap(src) {
  const out = {};
  if (!src || typeof src !== "object" || Array.isArray(src)) return out;
  for (const [key, value] of Object.entries(src)) {
    if (Number.isFinite(Number(value))) out[String(key).slice(0, 48)] = Number(value);
  }
  return out;
}

function safeXapi(src) {
  if (!src || typeof src !== "object" || Array.isArray(src)) return undefined;
  const result = src.result && typeof src.result === "object" && !Array.isArray(src.result) ? src.result : {};
  const extensions = result.extensions && typeof result.extensions === "object" && !Array.isArray(result.extensions)
    ? result.extensions : {};
  return {
    verb: src.verb ? String(src.verb).slice(0, 64) : "",
    result: {
      success: result.success === undefined ? undefined : Boolean(result.success),
      score: safeNumberMap(result.score),
      extensions: safeNumberMap(extensions),
    },
  };
}

function safeTelemetryEvent(e) {
  const clean = {};
  for (const key of TELEMETRY_STRING_FIELDS) {
    if (e[key] !== undefined && e[key] !== null) clean[key] = String(e[key]).slice(0, 96);
  }
  for (const key of TELEMETRY_NUMBER_FIELDS) {
    if (e[key] !== undefined && e[key] !== null && Number.isFinite(Number(e[key]))) clean[key] = Number(e[key]);
  }
  for (const key of TELEMETRY_BOOL_FIELDS) {
    if (e[key] !== undefined && e[key] !== null) clean[key] = Boolean(e[key]);
  }
  if (e.move && typeof e.move === "object" && !Array.isArray(e.move)) {
    clean.move = {
      ...copyStrings(e.move, ["tag", "input_mode"], 48),
      ...copyNumbers(e.move, ["wait_ms"]),
    };
  }
  if (e.judge && typeof e.judge === "object" && !Array.isArray(e.judge)) {
    clean.judge = {
      ...copyBools(e.judge, ["targets", "wait_ok", "ok"]),
      tags: Array.isArray(e.judge.tags) ? e.judge.tags.slice(0, 8).map((tag) => String(tag).slice(0, 48)) : [],
    };
  }
  clean.deltas = safeNumberMap(e.deltas);
  clean.meters = safeNumberMap(e.meters);
  const xapi = safeXapi(e.xapi);
  if (xapi) clean.xapi = xapi;
  return clean;
}

// Full-fidelity storage: preserve the WHOLE behavioral event (dialogue text, movement
// tiles, input keys, classroom choices, reflections) — not just a whitelist — but bound
// it so an unauthenticated client cannot write unbounded payloads to D1.
function clampJson(v, depth) {
  if (depth > 5) return null;
  if (typeof v === "string") return v.slice(0, 600);
  if (typeof v === "number") return Number.isFinite(v) ? v : null;
  if (typeof v === "boolean" || v === null) return v;
  if (Array.isArray(v)) return v.slice(0, 64).map((x) => clampJson(x, depth + 1));
  if (typeof v === "object") {
    const out = {};
    let i = 0;
    for (const [k, val] of Object.entries(v)) {
      if (i++ >= 64) break;
      out[String(k).slice(0, 48)] = clampJson(val, depth + 1);
    }
    return out;
  }
  return null;
}
function sanitizeEvent(e) {
  const clean = clampJson(e && typeof e === "object" ? e : {}, 0) || {};
  if (JSON.stringify(clean).length > 8000) {
    return {
      event: String(clean.event || "").slice(0, 96),
      session_id: String(clean.session_id || "").slice(0, 96),
      construct_id: clean.construct_id || null,
      _truncated: true,
    };
  }
  return clean;
}
// Server-trusted connection context: WHERE the player connects from (geo/referrer/agent).
// Cloudflare populates req.cf; we keep country/city grain (not raw IP) for privacy.
function connCtx(req) {
  const cf = req.cf || {};
  return {
    country: cf.country || null, city: cf.city || null, region: cf.region || null,
    colo: cf.colo || null, tz: cf.timezone || null, org: cf.asOrganization || null,
    referer: (req.headers.get("Referer") || "").slice(0, 200),
    ua: (req.headers.get("User-Agent") || "").slice(0, 200),
    lang: (req.headers.get("Accept-Language") || "").slice(0, 60),
  };
}

export default {
  async fetch(req, env) {
    if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
    const url = new URL(req.url);
    try {
      if (url.pathname === "/turn" && req.method === "POST") {
        if (!(await rateLimit(env, clientIp(req), "turn"))) return json({ error: "rate_limited" }, 429);
        return json(await handleTurn(req, env));
      }
      if (url.pathname === "/tts" && req.method === "POST") {
        if (!(await rateLimit(env, clientIp(req), "tts"))) return new Response(null, { status: 429, headers: CORS });
        return await handleTts(req, env);
      }
      if (url.pathname === "/voice_token" && req.method === "POST") {
        if (!(await rateLimit(env, clientIp(req), "voice_token"))) return json({ error: "rate_limited" }, 429);
        return await voiceToken(req, env);
      }
      if (url.pathname === "/group_turn" && req.method === "POST") {
        if (!(await rateLimit(env, clientIp(req), "turn"))) return json({ error: "rate_limited" }, 429);
        return json(await handleGroupTurn(req, env));
      }
      if (url.pathname === "/lecture_turn" && req.method === "POST") {
        if (!(await rateLimit(env, clientIp(req), "turn"))) return json({ error: "rate_limited" }, 429);
        return json(await handleLectureTurn(req, env));
      }
      if (url.pathname === "/auth/login" && req.method === "POST") return await login(req, env);
      if (url.pathname === "/me" && req.method === "GET") return await me(req, env);
      if (url.pathname === "/telemetry" && req.method === "POST") return await telemetry(req, env);
      if (url.pathname === "/telemetry_anon" && req.method === "POST") return await telemetryAnon(req, env);
      if (url.pathname === "/competency" && req.method === "POST") return await competency(req, env);
      if (url.pathname === "/competency" && req.method === "GET") return await competencyRead(req, env);
      if (url.pathname === "/class_dashboard" && req.method === "GET") return await classDashboard(req, env);
      return json({ error: "not found" }, 404);
    } catch (e) {
      return json({ error: String(e) }, 500);
    }
  },
};

async function voiceToken(req, env) {
  const raw = (await req.text()).replace(/^\uFEFF/, "");
  const { passcode } = JSON.parse(raw || "{}");
  const accepted = [env.TTS_PASSCODE, env.CAT531_PASSCODE, "CAT5312026", env.CAT100_PASSCODE, "CAT1002026"]
    .map((value) => String(value || "").trim())
    .filter((value, index, values) => value && values.indexOf(value) === index);
  if (!accepted.length) return json({ error: "voice access is not configured" }, 503);
  if (!(env.WORKER_SECRET || "").trim()) return json({ error: "voice signing is not configured" }, 503);
  if (!accepted.includes((passcode || "").trim())) return json({ error: "invalid passcode" }, 403);
  const expiresIn = 15 * 60;
  const token = await signVoiceToken(
    { scope: "tts", exp: Math.floor(Date.now() / 1000) + expiresIn },
    env.WORKER_SECRET);
  return json({ token, expires_in: expiresIn });
}

async function login(req, env) {
  const { class_code, name, password } = await req.json();
  if (!class_code || !name || !password) return json({ error: "class_code, name, password required" }, 400);
  const cls = await env.DB.prepare("SELECT * FROM classes WHERE class_code=?").bind(class_code).first();
  if (!cls) return json({ error: "unknown class code" }, 404);
  const coursePasscode = passcodeForClass(class_code, env);
  const usingCoursePasscode = coursePasscode && password === coursePasscode;
  const login_name = slug(name);
  let row = await env.DB.prepare("SELECT * FROM learners WHERE class_code=? AND login_name=?")
    .bind(class_code, login_name).first();

  if (!row) {
    if (!cls.join_open) return json({ error: "this class is not open for new sign-ups" }, 403);
    const { hash, salt } = await hashPw(password);
    const user_id = uuid();
    await env.DB.prepare(
      "INSERT INTO learners (user_id,class_code,login_name,display_name,pw_hash,pw_salt) VALUES (?,?,?,?,?,?)")
      .bind(user_id, class_code, login_name, name.trim(), hash, salt).run();
    row = { user_id, class_code, login_name, display_name: name.trim(), pw_hash: hash, pw_salt: salt, role: "learner" };
  } else {
    const { hash } = await hashPw(password, row.pw_salt);
    const role = row.role || "learner";
    if (hash !== row.pw_hash) {
      if (role === "learner" && usingCoursePasscode) {
        const reset = await hashPw(coursePasscode);
        await env.DB.prepare("UPDATE learners SET pw_hash=?, pw_salt=? WHERE user_id=?")
          .bind(reset.hash, reset.salt, row.user_id).run();
        row.pw_hash = reset.hash;
        row.pw_salt = reset.salt;
      } else {
        return json({ error: coursePasscode ? "wrong passcode" : "wrong password" }, 401);
      }
    }
  }
  const token = await signJWT(
    { sub: row.user_id, name: row.display_name, cls: class_code, role: row.role,
      exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30 }, env.WORKER_SECRET);
  return json({ token, user_id: row.user_id, display_name: row.display_name, class_code, role: row.role });
}

function passcodeForClass(classCode, env) {
  if (classCode === "UA-CAT531-SUMMER26") {
    return String(env.CAT531_PASSCODE || "CAT5312026").trim();
  }
  if (classCode === "UA-CAT100-SUMMER26") {
    return String(env.CAT100_PASSCODE || "CAT1002026").trim();
  }
  return "";
}

async function auth(req, env) {
  return verifyJWT(bearer(req), env.WORKER_SECRET);
}

async function me(req, env) {
  const p = await auth(req, env);
  if (!p) return json({ error: "unauthorized" }, 401);
  return json({ user_id: p.sub, display_name: p.name, class_code: p.cls, role: p.role });
}

async function telemetry(req, env) {
  const p = await auth(req, env);
  if (!p) return json({ error: "unauthorized" }, 401);
  const { events } = await req.json();
  if (!Array.isArray(events)) return json({ error: "events[] required" }, 400);
  const ctx = connCtx(req);
  const stmt = env.DB.prepare(
    "INSERT INTO telemetry_events (user_id,session_id,construct_id,event) VALUES (?,?,?,?)");
  const batch = events.slice(0, 500).map((e) => {
    const clean = sanitizeEvent(e || {});
    if (clean.event === "session_start" && !clean.conn) clean.conn = ctx;  // where they connect from
    return stmt.bind(p.sub, String(clean.session_id || ""), clean.construct_id || null, JSON.stringify(clean));
  });
  if (batch.length) await env.DB.batch(batch);
  return json({ stored: batch.length });
}

// Anonymous / demo telemetry — no login. Events are namespaced under 'anon:<id>' so they
// can never impersonate a real learner, rate-limited per IP, and full-fidelity like the
// authed path. This is what makes public demo play minable.
async function telemetryAnon(req, env) {
  if (!(await rateLimit(env, clientIp(req), "tel_anon"))) return json({ error: "rate_limited" }, 429);
  let body;
  try { body = await req.json(); } catch (_e) { return json({ error: "bad json" }, 400); }
  const events = body && Array.isArray(body.events) ? body.events : null;
  if (!events) return json({ error: "events[] required" }, 400);
  const anon = slug(body.anon_id) || "unknown";
  const ctx = connCtx(req);
  // Separate FK-free table so demo rows need no learners row (D1 enforces foreign keys).
  const stmt = env.DB.prepare(
    "INSERT INTO telemetry_anon_events (anon_id,session_id,construct_id,event) VALUES (?,?,?,?)");
  const batch = events.slice(0, 500).map((e) => {
    const clean = sanitizeEvent(e || {});
    clean.anon = true;
    if (clean.event === "session_start" && !clean.conn) clean.conn = ctx;  // where they connect from
    return stmt.bind(anon, String(clean.session_id || ""), clean.construct_id || null, JSON.stringify(clean));
  });
  if (batch.length) await env.DB.batch(batch);
  return json({ stored: batch.length });
}

async function competency(req, env) {
  const p = await auth(req, env);
  if (!p) return json({ error: "unauthorized" }, 401);
  const { skills } = await req.json();
  if (!Array.isArray(skills)) return json({ error: "skills[] required" }, 400);
  const stmt = env.DB.prepare(
    `INSERT INTO competency (user_id,skill,theta,prob,n,updated_at) VALUES (?,?,?,?,?,datetime('now'))
     ON CONFLICT(user_id,skill) DO UPDATE SET theta=excluded.theta, prob=excluded.prob, n=excluded.n, updated_at=excluded.updated_at`);
  const batch = skills.slice(0, 64).map((s) =>
    stmt.bind(p.sub, String(s.skill), Number(s.theta) || 0, Number(s.prob) || 0.5, Number(s.n) || 0));
  if (batch.length) await env.DB.batch(batch);
  return json({ upserted: batch.length });
}

async function competencyRead(req, env) {
  const p = await auth(req, env);
  if (!p) return json({ error: "unauthorized" }, 401);
  const { results } = await env.DB.prepare(
    "SELECT skill,theta,prob,n,updated_at FROM competency WHERE user_id=? ORDER BY updated_at DESC, skill ASC")
    .bind(p.sub).all();
  return json({ skills: results || [] });
}

function classInterventions(skills) {
  const rows = (skills || []).slice(0, 3);
  if (!rows.length) {
    return ["Collect one completed mission per learner before assigning class-wide reteach stations."];
  }
  return rows.map((row) => {
    const skill = row.skill || "target skill";
    const risk = Number(row.at_risk || 0);
    const avg = Math.round(Number(row.avg_prob || 0.5) * 100);
    if (risk > 0) return `Run a small-group rehearsal on ${skill}; ${risk} learner(s) are below the live support threshold.`;
    return `Use ${skill} as tomorrow's warm-up check; class average is ${avg}%.`;
  });
}

async function classDashboard(req, env) {
  const p = await auth(req, env);
  if (!p) return json({ error: "unauthorized" }, 401);
  if (p.role !== "instructor") return json({ error: "forbidden" }, 403);
  const learners = await env.DB.prepare(
    "SELECT COUNT(*) AS n FROM learners WHERE class_code=? AND role='learner'")
    .bind(p.cls).first();
  const telemetryRows = await env.DB.prepare(
    "SELECT COUNT(*) AS n FROM telemetry_events t JOIN learners l ON t.user_id=l.user_id WHERE l.class_code=? AND l.role='learner'")
    .bind(p.cls).first();
  const activity = await env.DB.prepare(
    `SELECT COUNT(DISTINCT t.session_id) AS sessions,
            COUNT(DISTINCT CASE
              WHEN json_extract(t.event,'$.event') IN ('resolve','lecture_resolve','group_resolve','gym_resolve') THEN t.session_id
            END) AS completed_sessions,
            COUNT(DISTINCT CASE WHEN t.created_at >= datetime('now','-1 day') THEN t.user_id END) AS active_24h,
            MAX(t.created_at) AS last_event_at
       FROM telemetry_events t JOIN learners l ON t.user_id=l.user_id
      WHERE l.class_code=? AND l.role='learner'`)
    .bind(p.cls).first();
  const { results } = await env.DB.prepare(
    `SELECT c.skill AS skill, COUNT(*) AS learners, ROUND(AVG(c.prob), 3) AS avg_prob,
            SUM(c.n) AS evidence, ROUND(MIN(c.prob), 3) AS min_prob, ROUND(MAX(c.prob), 3) AS max_prob,
            SUM(CASE WHEN c.prob < 0.45 THEN 1 ELSE 0 END) AS at_risk,
            SUM(CASE WHEN c.prob >= 0.70 THEN 1 ELSE 0 END) AS ready
       FROM competency c JOIN learners l ON c.user_id=l.user_id
      WHERE l.class_code=? AND l.role='learner'
      GROUP BY c.skill
      ORDER BY avg_prob ASC, evidence DESC`)
    .bind(p.cls).all();
  const { results: modes } = await env.DB.prepare(
    `SELECT COALESCE(NULLIF(json_extract(t.event,'$.mode'),''), json_extract(t.event,'$.event'), 'event') AS mode,
            COUNT(*) AS events,
            COUNT(DISTINCT t.session_id) AS sessions
       FROM telemetry_events t JOIN learners l ON t.user_id=l.user_id
      WHERE l.class_code=? AND l.role='learner'
      GROUP BY mode
      ORDER BY events DESC
      LIMIT 6`)
    .bind(p.cls).all();
  const { results: learnerRows } = await env.DB.prepare(
    `WITH activity AS (
       SELECT user_id, COUNT(*) AS events, COUNT(DISTINCT session_id) AS sessions, MAX(created_at) AS last_active
         FROM telemetry_events
        GROUP BY user_id
     ), skill_avg AS (
       SELECT user_id, ROUND(AVG(prob), 3) AS avg_prob, SUM(n) AS evidence
         FROM competency
        GROUP BY user_id
     )
     SELECT l.display_name,
            COALESCE(a.events, 0) AS events,
            COALESCE(a.sessions, 0) AS sessions,
            a.last_active AS last_active,
            COALESCE(s.avg_prob, 0.5) AS avg_prob,
            COALESCE(s.evidence, 0) AS evidence,
            (SELECT skill FROM competency c WHERE c.user_id=l.user_id ORDER BY c.prob ASC, c.n DESC LIMIT 1) AS weakest_skill
       FROM learners l
      LEFT JOIN activity a ON a.user_id=l.user_id
      LEFT JOIN skill_avg s ON s.user_id=l.user_id
      WHERE l.class_code=? AND l.role='learner'
      ORDER BY avg_prob ASC, last_active DESC
      LIMIT 8`)
    .bind(p.cls).all();
  const skills = results || [];
  const sessions = Number(activity?.sessions || 0);
  const completed = Number(activity?.completed_sessions || 0);
  return json({
    class_code: p.cls,
    role: p.role,
    learners: Number(learners?.n || 0),
    telemetry_events: Number(telemetryRows?.n || 0),
    activity: {
      sessions,
      completed_sessions: completed,
      completion_rate: sessions > 0 ? Number((completed / sessions).toFixed(3)) : 0,
      active_24h: Number(activity?.active_24h || 0),
      last_event_at: activity?.last_event_at || "",
    },
    skills,
    modes: modes || [],
    learners_detail: learnerRows || [],
    interventions: classInterventions(skills),
  });
}
