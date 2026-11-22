"""READ-ONLY: list the test-traffic rows described in docs/test-traffic-2026-11.md.

Storage (cloudflare/worker.js): Cloudflare D1 (SQLite), database "chalk_db", table
telemetry_anon_events (id, anon_id, session_id, construct_id, event JSON, created_at UTC).
Test runs were never signed in, so telemetry_events (named learners) holds none of it, and
/turn calls are not stored at all.

A browser id (anon_id) is test traffic if ANY of its rows carries one of the marks:
  - anon_id starts with "ci_anon_"                       (AnonTelemetryTest)
  - event.engine == "anon_test"                          (AnonTelemetryTest)
  - event.client.url starts "http://127.0.0.1:876"       (local exports, ports 8762/8763)
  - event.client.ua or event.conn.ua contains "HeadlessChrome"
  - event.conn.referer starts "http://127.0.0.1:876"
Every run used a fresh browser profile, so all rows of a marked anon_id are test rows.
anon_id "unknown" (no id sent) is shared, so there only the marked session_ids are taken.

Run it yourself (it only issues one SELECT):
  python tools/ops/find_test_telemetry.py --wrangler --out test_rows.json     # remote D1
  python tools/ops/find_test_telemetry.py --sqlite local.db --out test_rows.json
Review test_rows.json, then see tools/ops/delete_test_telemetry.py.
"""
import argparse
import json
import os
import sqlite3
import subprocess
import sys
import tempfile

MARK = """(
    anon_id LIKE 'ci!_anon!_%' ESCAPE '!'
 OR json_extract(event,'$.engine') = 'anon_test'
 OR json_extract(event,'$.client.url') LIKE 'http://127.0.0.1:876%'
 OR json_extract(event,'$.client.ua') LIKE '%HeadlessChrome%'
 OR json_extract(event,'$.conn.ua') LIKE '%HeadlessChrome%'
 OR json_extract(event,'$.conn.referer') LIKE 'http://127.0.0.1:876%'
)"""

QUERY = f"""SELECT id, anon_id, session_id, created_at, json_extract(event,'$.event') AS ev,
  CASE WHEN {MARK} THEN 1 ELSE 0 END AS marked
FROM telemetry_anon_events
WHERE (anon_id <> 'unknown' AND anon_id IN (SELECT anon_id FROM telemetry_anon_events WHERE {MARK}))
   OR (anon_id = 'unknown' AND session_id IN (SELECT session_id FROM telemetry_anon_events WHERE anon_id = 'unknown' AND {MARK}))
ORDER BY created_at, id"""

assert QUERY.lstrip().upper().startswith("SELECT") and ";" not in QUERY   # one read, nothing else
COLS = ["id", "anon_id", "session_id", "created_at", "ev", "marked"]


def rows_sqlite(path):
    con = sqlite3.connect("file:%s?mode=ro" % path, uri=True)   # read-only connection
    try:
        return [dict(zip(COLS, r)) for r in con.execute(QUERY)]
    finally:
        con.close()


def rows_wrangler(db, remote):
    # The SQL goes through a file: on Windows wrangler is a .cmd and cmd.exe would re-parse
    # quotes and % signs in a --command argument.
    sql = os.path.join(tempfile.mkdtemp(), "find_test_telemetry.sql")
    open(sql, "w", encoding="utf8").write(QUERY + ";\n")
    cmd = ["wrangler", "d1", "execute", db, "--json", "--file", sql] + (["--remote"] if remote else [])
    out = subprocess.run(cmd, capture_output=True, text=True, check=True, shell=sys.platform == "win32").stdout
    return json.loads(out)[0]["results"]


def summarize(rows):
    ids = {}
    for r in rows:
        a = ids.setdefault(r["anon_id"], {"rows": 0, "first": r["created_at"], "last": r["created_at"], "sessions": set()})
        a["rows"] += 1
        a["last"] = r["created_at"]
        a["sessions"].add(r["session_id"])
    return ids


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--sqlite", help="local SQLite file (an exported copy or a fixture)")
    src.add_argument("--wrangler", action="store_true", help="query D1 through wrangler (read-only SELECT)")
    ap.add_argument("--db", default="chalk_db")
    ap.add_argument("--local-d1", action="store_true", help="with --wrangler: the local dev D1, not --remote")
    ap.add_argument("--out", help="write the reviewed list here (input for delete_test_telemetry.py)")
    a = ap.parse_args()
    rows = rows_sqlite(a.sqlite) if a.sqlite else rows_wrangler(a.db, not a.local_d1)
    ids = summarize(rows)
    print("test-traffic rows: %d in %d browser ids (table telemetry_anon_events)" % (len(rows), len(ids)))
    print("%-28s %5s  %-19s  %-19s  %s" % ("anon_id", "rows", "first (UTC)", "last (UTC)", "sessions"))
    for k, v in sorted(ids.items(), key=lambda kv: kv[1]["first"]):
        print("%-28s %5d  %-19s  %-19s  %d" % (k[:28], v["rows"], v["first"], v["last"], len(v["sessions"])))
    if a.out:
        json.dump({"table": "telemetry_anon_events", "query": QUERY, "rows": rows}, open(a.out, "w", encoding="utf8"), indent=1)
        print("wrote %s (%d rows). Review it before running the delete script." % (a.out, len(rows)))


if __name__ == "__main__":
    main()
