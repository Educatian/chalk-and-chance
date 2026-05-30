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

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
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
const slug = (s) => (s || "").trim().toLowerCase().replace(/\s+/g, "_").slice(0, 40);

export default {
  async fetch(req, env) {
    if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
    const url = new URL(req.url);
    try {
      if (url.pathname === "/turn" && req.method === "POST") return json(await handleTurn(req, env));
      if (url.pathname === "/auth/login" && req.method === "POST") return login(req, env);
      if (url.pathname === "/me" && req.method === "GET") return me(req, env);
      if (url.pathname === "/telemetry" && req.method === "POST") return telemetry(req, env);
      if (url.pathname === "/competency" && req.method === "POST") return competency(req, env);
      return json({ error: "not found" }, 404);
    } catch (e) {
      return json({ error: String(e) }, 500);
    }
  },
};

async function login(req, env) {
  const { class_code, name, password } = await req.json();
  if (!class_code || !name || !password) return json({ error: "class_code, name, password required" }, 400);
  const cls = await env.DB.prepare("SELECT * FROM classes WHERE class_code=?").bind(class_code).first();
  if (!cls) return json({ error: "unknown class code" }, 404);
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
    if (hash !== row.pw_hash) return json({ error: "wrong password" }, 401);
  }
  const token = await signJWT(
    { sub: row.user_id, name: row.display_name, cls: class_code, role: row.role,
      exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30 }, env.WORKER_SECRET);
  return json({ token, user_id: row.user_id, display_name: row.display_name, class_code, role: row.role });
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
  const stmt = env.DB.prepare(
    "INSERT INTO telemetry_events (user_id,session_id,construct_id,event) VALUES (?,?,?,?)");
  const batch = events.slice(0, 500).map((e) =>
    stmt.bind(p.sub, String(e.session_id || ""), e.construct_id || null, JSON.stringify(e)));
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
