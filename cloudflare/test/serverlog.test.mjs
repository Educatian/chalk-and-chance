// server_log: migration on a local SQLite copy of schema.sql, one row per request with the
// diag, a failed log write never affects the response, no secret/token/IP in any row, and
// the R2 archive (off by default; verified before anything is pruned). No network.
// Run: node --test cloudflare/test/serverlog.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import worker from "../worker.js";
import { archiveServerLog } from "../serverlog.js";

const read = (f) => readFileSync(new URL(f, import.meta.url), "utf8");
const SCHEMA = read("../schema.sql");
const MIGRATION = read("../migrations/0001_server_log.sql");

// Minimal D1 API over node:sqlite.
function d1(db, failOn = null) {
  const stmt = (sql, args = []) => ({
    bind: (...a) => stmt(sql, a),
    run: async () => {
      if (failOn && sql.includes(failOn)) throw new Error("D1 write failed");
      return { meta: { changes: Number(db.prepare(sql).run(...args).changes) } };
    },
    first: async () => db.prepare(sql).get(...args) ?? null,
    all: async () => ({ results: db.prepare(sql).all(...args) }),
  });
  return { prepare: (sql) => stmt(sql), batch: async (list) => Promise.all(list.map((x) => x.run())) };
}
function freshDb({ migrate = true } = {}) {
  const db = new DatabaseSync(":memory:");
  db.exec(SCHEMA);
  if (migrate) db.exec(MIGRATION);
  db.exec("INSERT INTO classes(class_code,name) VALUES('T-CLASS','Test')");
  return db;
}
const SECRETS = { WORKER_SECRET: "worker-secret-0123456789", OPENROUTER_API_KEY: "sk-or-v1-abcdef0123456789",
  TTS_PASSCODE: "voice-pass-42", CF_VERSION_METADATA: { id: "ver-test-1" } };

async function call(env, path, { method = "POST", body, headers = {} } = {}) {
  const pending = [];
  const req = new Request("https://api.test" + path, { method,
    headers: { "Content-Type": "application/json", "CF-Connecting-IP": "203.0.113.7", ...headers },
    body: body === undefined ? undefined : typeof body === "string" ? body : JSON.stringify(body) });
  const res = await worker.fetch(req, env, { waitUntil: (p) => pending.push(p) });
  const settled = await Promise.allSettled(pending);
  return { res, text: await res.text(), settled };
}
const say = (t) => JSON.stringify({ text: t, emotion_shown: "thinking" });
function stubModel(students, coach = '{"coach_tip":"더 묻기로 아이가 스스로 따져 보게 했어요."}') {
  globalThis.fetch = async (url, init) => {
    if (!String(url).includes("openrouter")) throw new Error("no network in tests");
    const sys = JSON.parse(init.body).messages[0].content;
    const next = sys.includes("coach_tip") ? coach : students.shift() ?? say("음…");
    return { ok: true, status: 200, json: async () => ({ choices: [{ finish_reason: "stop", message: { content: next } }] }) };
  };
}
const turnBody = (extra = {}) => ({ session_id: "m1", active_persona_id: "noah_g5_fractions", locale: "ko",
  runtime_state: { understanding: 0.15 }, win_moves: ["elicit", "extend", "revoice", "wait"],
  teacher_move: { input_mode: "menu", menu_tag: "extend", wait_time_ms: 3000 },
  move_history: [{ tag: "elicit" }], dialogue_tail: [], ...extra });

test("migration is additive: existing tables unchanged, safe to apply twice, ts index exists", () => {
  const db = new DatabaseSync(":memory:");
  db.exec(SCHEMA);
  const before = db.prepare("SELECT name, sql FROM sqlite_master ORDER BY name").all();
  db.exec(MIGRATION);
  db.exec(MIGRATION);
  const after = db.prepare("SELECT name, sql FROM sqlite_master ORDER BY name").all();
  for (const t of before) assert.deepEqual(after.find((x) => x.name === t.name), t, t.name);
  assert.deepEqual(after.filter((x) => !before.some((b) => b.name === x.name)).map((x) => x.name).sort(),
    ["server_log", "server_log_ts_idx", "sqlite_sequence"].filter((n) => !before.some((b) => b.name === n)).sort());
});

test("one row per /turn with the full diag (rejected texts kept in the log, not in the response)", async () => {
  const db = freshDb();
  const line = "음… 선생님 말이 맞는 것 같기도 해요. 근데 8이 더 크잖아요.";
  stubModel([say(line), say(line)]);
  const { res, text } = await call({ ...SECRETS, DB: d1(db) }, "/turn", { body: turnBody() });
  assert.equal(res.status, 200);
  assert.equal(JSON.parse(text).diag.student.rejected, undefined);      // response unchanged
  const rows = db.prepare("SELECT * FROM server_log").all();
  assert.equal(rows.length, 1);
  const r = rows[0];
  assert.deepEqual([r.route, r.method, r.status, r.locale, r.persona, r.move, r.input_mode, r.session_id, r.worker_version],
    ["/turn", "POST", 200, "ko", "noah_g5_fractions", "extend", "menu", "m1", "ver-test-1"]);
  const diag = JSON.parse(r.diag);
  assert.deepEqual([diag.student.source, diag.student.rule, diag.student.attempts], ["retry", "leak:teacher_is_right", 2]);
  assert.deepEqual(diag.student.rejected, [line, line]);   // both attempts, as diag records them
  assert.equal(diag.coach.source, "model");
  assert.match(r.ts, /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/);
  assert.ok(r.latency_ms >= 0);
});

test("a failed log write never affects the response", async () => {
  for (const env of [
    { ...SECRETS, DB: d1(freshDb({ migrate: false })) },              // table not created yet
    { ...SECRETS, DB: d1(freshDb(), "INSERT INTO server_log") },      // D1 write error
  ]) {
    stubModel([say("8분의 1이 더 커요.")]);
    const { res, text, settled } = await call(env, "/turn", { body: turnBody() });
    assert.equal(res.status, 200);
    assert.equal(JSON.parse(text).student_utterance.text, "8분의 1이 더 커요.");
    assert.ok(settled.every((s) => s.status === "fulfilled"), "waitUntil promise must not reject");
  }
});

test("no secret, password, passcode, token or raw IP ever appears in a row", async () => {
  const db = freshDb();
  const env = { ...SECRETS, DB: d1(db) };
  const password = "hunter2-password";
  const login = await call(env, "/auth/login", { body: { class_code: "T-CLASS", name: "Kim", password } });
  const { token, user_id } = JSON.parse(login.text);
  await call(env, "/auth/login", { body: `{"class_code":"T-CLASS","name":"Kim","password":"${password}"` });  // malformed
  await call(env, "/auth/login", { body: { class_code: "T-CLASS", name: "Kim", password: "wrong-pass-77" } });
  await call(env, "/voice_token", { body: { passcode: SECRETS.TTS_PASSCODE } });
  await call(env, "/voice_token", { body: { passcode: "CAT5312026" } });
  await call(env, "/telemetry", { body: { events: [{ event: "session_start", session_id: "s1" }] },
    headers: { Authorization: "Bearer " + token } });
  await call(env, "/me", { method: "GET", headers: { Authorization: "Bearer not.a.valid-token-xxxxxxxxxxxxxxxx" } });
  await call(env, "/tts", { body: { persona_id: "noah_g5_fractions", text: "안녕" }, headers: { "X-Voice-Token": "vt-secret-token-9999" } });
  await call(env, "/telemetry_anon", { body: { anon_id: "a_1_2", events: [{ event: "session_start", session_id: "sess_9" }] } });
  stubModel([say("음… 왜요?")]);
  await call(env, "/turn", { body: turnBody({ teacher_move: { input_mode: "free_text", text: "내 비밀 메모 hunter2", wait_time_ms: 0 } }) });

  const rows = db.prepare("SELECT * FROM server_log ORDER BY id").all();
  assert.equal(rows.length, 10);
  const dump = JSON.stringify(rows);
  for (const bad of [password, "wrong-pass-77", SECRETS.WORKER_SECRET, SECRETS.OPENROUTER_API_KEY, SECRETS.TTS_PASSCODE,
    "CAT5312026", token, "vt-secret-token-9999", "203.0.113.7", "내 비밀 메모", "hunter2"]) {
    assert.ok(!dump.includes(bad), "row contains " + bad);
  }
  const byRoute = (p) => rows.filter((r) => r.route === p);
  assert.deepEqual(byRoute("/auth/login").map((r) => r.status), [200, 500, 401]);
  assert.equal(byRoute("/auth/login")[1].error, "SyntaxError");                    // name only on login
  assert.equal(byRoute("/telemetry")[0].user_id, user_id);                         // verified learner id
  assert.equal(byRoute("/me")[0].user_id, null);                                   // invalid token: no id
  assert.equal(byRoute("/me")[0].status, 401);
  assert.deepEqual([byRoute("/telemetry_anon")[0].anon_id, byRoute("/telemetry_anon")[0].session_id], ["a_1_2", "sess_9"]);
  const t = byRoute("/turn")[0];
  assert.deepEqual([t.input_mode, t.text_len], ["free_text", "내 비밀 메모 hunter2".length]);
});

// --- archive ---------------------------------------------------------------------------
function fakeR2({ corrupt = false } = {}) {
  const store = new Map();
  const obj = (v) => ({ text: async () => new TextDecoder().decode(v), arrayBuffer: async () => v });
  return {
    store,
    put: async (k, v) => {
      let buf = typeof v === "string" ? new TextEncoder().encode(v) : new Uint8Array(v);
      if (corrupt && k.endsWith(".gz")) buf = buf.slice(0, buf.length - 4);
      store.set(k, buf);
    },
    get: async (k) => (store.has(k) ? obj(store.get(k)) : null),
  };
}
function seedLog(db, rows) {
  const ins = db.prepare("INSERT INTO server_log (ts,route,method,status,latency_ms,diag) VALUES (?,?,?,?,?,?)");
  for (const [ts, i] of rows) ins.run(ts, "/turn", "POST", 200, 10 + i, JSON.stringify({ student: { source: "model" } }));
}
const gunzip = async (buf) => new Response(new Blob([buf]).stream().pipeThrough(new DecompressionStream("gzip"))).text();

test("archive is off unless LOG_BUCKET is bound and LOG_ARCHIVE is on", async () => {
  const db = freshDb();
  assert.deepEqual(await archiveServerLog({ DB: d1(db) }), { skipped: "off" });
  assert.deepEqual(await archiveServerLog({ DB: d1(db), LOG_BUCKET: fakeR2() }), { skipped: "off" });
});

test("archive: verified gzipped NDJSON in R2, cursor in the manifest, prune only archived old rows", async () => {
  const db = freshDb();
  const now = new Date("2027-03-01T03:17:00Z");
  seedLog(db, [["2025-12-05T10:00:00.000Z", 1], ["2026-01-10T10:00:00.000Z", 2], ["2027-02-20T10:00:00.000Z", 3],
    ["2027-03-01T03:00:00.000Z", 4]]);   // the last one is < 1 hour old: not archived this run
  const bucket = fakeR2();
  const out = await archiveServerLog({ DB: d1(db), LOG_BUCKET: bucket, LOG_ARCHIVE: "on", LOG_KEEP_MONTHS: "12" }, now);
  assert.deepEqual(out.written, ["server_log/2025-12/1-3.ndjson.gz"]);
  const lines = (await gunzip(bucket.store.get(out.written[0]))).trim().split("\n").map((l) => JSON.parse(l));
  assert.deepEqual(lines.map((r) => r.id), [1, 2, 3]);
  const manifest = JSON.parse(new TextDecoder().decode(bucket.store.get("server_log/manifest.json")));
  assert.equal(manifest.cursor, 3);
  assert.equal(manifest.objects[0].rows, 3);
  // only rows archived AND older than 12 months are gone from D1
  assert.equal(out.pruned, 2);
  assert.deepEqual(db.prepare("SELECT id FROM server_log ORDER BY id").all().map((r) => r.id), [3, 4]);
  // next run continues after the cursor, nothing archived twice
  const out2 = await archiveServerLog({ DB: d1(db), LOG_BUCKET: bucket, LOG_ARCHIVE: "on" }, new Date("2027-03-01T05:00:00Z"));
  assert.deepEqual(out2.written, ["server_log/2027-03/4-4.ndjson.gz"]);
});

test("archive: a failed verification moves no cursor and prunes nothing", async () => {
  const db = freshDb();
  seedLog(db, [["2024-01-01T00:00:00.000Z", 1], ["2024-02-01T00:00:00.000Z", 2]]);
  const bucket = fakeR2({ corrupt: true });
  await assert.rejects(archiveServerLog({ DB: d1(db), LOG_BUCKET: bucket, LOG_ARCHIVE: "on" }, new Date("2027-03-01T00:00:00Z")));
  assert.equal(bucket.store.has("server_log/manifest.json"), false);
  assert.equal(db.prepare("SELECT COUNT(*) n FROM server_log").get().n, 2);
});
