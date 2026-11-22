"""End-to-end self-check: the Worker's archive job (cloudflare/serverlog.js, run in Node against a
local SQLite file and a folder standing in for R2) writes an archive, then verify_archive.py
checks it through a fake wrangler. No network, no account.
Run: python -I tools/logs/test_verify_archive.py"""
import os
import sqlite3
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
FAKE = r'''import json, os, sqlite3, sys
a = sys.argv[1:]
if a[:3] == ["r2", "object", "get"]:
    sys.stdout.buffer.write(open(os.path.join(os.environ["FAKE_R2"], *a[3].split("/", 1)[1].split("/")), "rb").read())
elif a[:2] == ["d1", "execute"]:
    assert a[a.index("--command") + 1].lstrip().upper().startswith("SELECT"), "verifier must only SELECT"
    con = sqlite3.connect(os.environ["FAKE_D1"]); con.row_factory = sqlite3.Row
    rows = [dict(r) for r in con.execute(a[a.index("--command") + 1])]
    print(json.dumps([{"results": rows, "success": True}]))
'''
JOB = r'''
import { DatabaseSync } from "node:sqlite";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { pathToFileURL } from "node:url";
const [root, dbPath, r2Dir] = process.argv.slice(2);
const { archiveOnDemand } = await import(pathToFileURL(join(root, "cloudflare/serverlog.js")).href);
const db = new DatabaseSync(dbPath);
db.exec(readFileSync(join(root, "cloudflare/schema.sql"), "utf8"));
db.exec(readFileSync(join(root, "cloudflare/migrations/0001_server_log.sql"), "utf8"));
const ins = db.prepare("INSERT INTO server_log (ts,route,method,status,latency_ms,locale,diag) VALUES (?,?,?,?,?,?,?)");
for (let i = 0; i < 25; i++) ins.run(new Date(Date.now() - (50 - i) * 3600e3).toISOString(), "/turn", "POST", 200, 500 + i, "ko",
  JSON.stringify({ student: { source: "model", rejected: ["음… 8분의 1이 더 커요."] } }));
const stmt = (sql, args = []) => ({ bind: (...a) => stmt(sql, a),
  run: async () => ({ meta: { changes: Number(db.prepare(sql).run(...args).changes) } }),
  first: async () => db.prepare(sql).get(...args) ?? null, all: async () => ({ results: db.prepare(sql).all(...args) }) });
const file = (k) => join(r2Dir, ...k.split("/"));
const bucket = {
  put: async (k, v) => { mkdirSync(dirname(file(k)), { recursive: true }); writeFileSync(file(k), typeof v === "string" ? v : Buffer.from(v)); },
  get: async (k) => { try { const b = readFileSync(file(k)); return { text: async () => b.toString("utf8"),
    arrayBuffer: async () => b.buffer.slice(b.byteOffset, b.byteOffset + b.length) }; } catch { return null; } },
};
const out = await archiveOnDemand({ DB: { prepare: (sql) => stmt(sql) }, LOG_BUCKET: bucket, LOG_ARCHIVE: "on" });
if (!out.pass) { console.error(JSON.stringify(out)); process.exit(1); }
'''

with tempfile.TemporaryDirectory() as tmp:
    db, r2 = os.path.join(tmp, "d1.sqlite"), os.path.join(tmp, "r2")
    job, fake = os.path.join(tmp, "job.mjs"), os.path.join(tmp, "fake_wrangler.py")
    open(job, "w", encoding="utf8").write(JOB)
    open(fake, "w", encoding="utf8").write(FAKE)
    subprocess.run(["node", job, ROOT, db, r2], check=True)
    cmd = [sys.executable, "-I", os.path.join(HERE, "verify_archive.py"),
           "--wrangler", "%s -I %s" % (sys.executable.replace("\\", "/"), fake.replace("\\", "/"))]
    env = {**os.environ, "FAKE_R2": r2, "FAKE_D1": db}
    v = lambda: subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="utf8")  # noqa: E731
    out = v()
    assert out.returncode == 0 and "RESULT: PASS" in out.stdout, out.stdout + out.stderr
    con = sqlite3.connect(db)
    con.execute("DELETE FROM server_log WHERE id = 7")                     # a pruned row
    con.commit()
    out = v()
    assert out.returncode == 1 and "FAIL  nothing pruned from D1" in out.stdout, out.stdout
    con.execute("UPDATE server_log SET status = 500 WHERE id = 8")          # D1 and archive disagree
    con.commit()
    out = v()
    assert "rows identical to D1  (differ: [8])" in out.stdout, out.stdout
    con.close()
print("verify_archive self-check: ok")
