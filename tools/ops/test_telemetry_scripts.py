"""Local check for find_/delete_test_telemetry.py on a fixture D1 copy (never the hosted store).
python -I tools/ops/test_telemetry_scripts.py"""
import json
import os
import sqlite3
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))


def ev(name, sid, **kw):
    return json.dumps(dict(event=name, session_id=sid, **kw))


def fixture(path):
    con = sqlite3.connect(path)
    con.executescript(open(os.path.join(ROOT, "cloudflare", "schema.sql"), encoding="utf8").read())
    rows = [
        # AnonTelemetryTest
        ("ci_anon_251321", "s1", ev("session_start", "s1", engine="anon_test", client={"url": "test://anon"}), "2026-11-21 06:24:01"),
        ("ci_anon_251321", "s1", ev("heartbeat", "s1"), "2026-11-21 06:24:02"),
        # headless debug export (local URL + HeadlessChrome), plus its later rows
        ("a_1763730000_1", "sess_1", ev("session_start", "sess_1", engine="4.7.2.stable.official.ed1daf0bf",
            client={"url": "http://127.0.0.1:8763/index.html?dev_win=noah", "ua": "Mozilla/5.0 HeadlessChrome/140"}), "2026-11-21 14:01:00"),
        ("a_1763730000_1", "sess_1", ev("turn", "sess_1", tag="elicit"), "2026-11-21 14:01:20"),
        # public site opened headless (only the UA marks it)
        ("a_1763740000_2", "sess_2", ev("session_start", "sess_2",
            client={"url": "https://educatian.github.io/chalk-and-chance-play/?public_demo=1", "ua": "x"},
            conn={"ua": "Mozilla/5.0 HeadlessChrome/140", "referer": ""}), "2026-11-21 15:10:00"),
        # real players: must never be listed
        ("a_1763700000_9", "sess_9", ev("session_start", "sess_9", engine="4.7.2.stable.official.ed1daf0bf",
            client={"url": "https://educatian.github.io/chalk-and-chance-play/", "ua": "Mozilla/5.0 Chrome/140"}), "2026-11-21 14:02:00"),
        ("a_1763700000_9", "sess_9", ev("turn", "sess_9"), "2026-11-21 14:02:30"),
        # shared "unknown" id: only the marked session goes
        ("unknown", "sess_u1", ev("session_start", "sess_u1", client={"url": "http://127.0.0.1:8762/index.html", "ua": "x"}), "2026-11-21 13:20:00"),
        ("unknown", "sess_u1", ev("turn", "sess_u1"), "2026-11-21 13:20:05"),
        ("unknown", "sess_u2", ev("session_start", "sess_u2", client={"url": "https://example.org/", "ua": "Chrome"}), "2026-11-21 13:21:00"),
    ]
    con.executemany("INSERT INTO telemetry_anon_events (anon_id,session_id,event,created_at) VALUES (?,?,?,?)", rows)
    con.commit()
    con.close()


def run(*args):
    r = subprocess.run([sys.executable, "-I"] + list(args), capture_output=True, text=True)
    print("$ %s\n%s(exit %d)" % (" ".join(os.path.basename(a) if a.endswith(".py") else a for a in args), r.stdout, r.returncode))
    return r


def main():
    d = tempfile.mkdtemp()
    db, lst = os.path.join(d, "fixture.db"), os.path.join(d, "test_rows.json")
    fixture(db)
    find, delete = os.path.join(HERE, "find_test_telemetry.py"), os.path.join(HERE, "delete_test_telemetry.py")
    r = run(find, "--sqlite", db, "--out", lst)
    listed = json.load(open(lst, encoding="utf8"))["rows"]
    assert len(listed) == 7, len(listed)
    assert {x["anon_id"] for x in listed} == {"ci_anon_251321", "a_1763730000_1", "a_1763740000_2", "unknown"}
    assert all(x["session_id"] != "sess_u2" for x in listed) and all(x["anon_id"] != "a_1763700000_9" for x in listed)
    r = run(delete, "--list", lst, "--sqlite", db)
    assert r.returncode == 2
    assert sqlite3.connect(db).execute("SELECT COUNT(*) FROM telemetry_anon_events").fetchone()[0] == 10, "dry run deleted"
    r = run(delete, "--list", lst, "--sqlite", db, "--confirm")
    assert r.returncode == 0
    left = sqlite3.connect(db).execute("SELECT anon_id, session_id FROM telemetry_anon_events ORDER BY id").fetchall()
    assert left == [("a_1763700000_9", "sess_9"), ("a_1763700000_9", "sess_9"), ("unknown", "sess_u2")], left
    r = run(find, "--sqlite", db)
    assert "rows: 0" in r.stdout
    print("TELEMETRY SCRIPTS PASS (fixture only; hosted store untouched)")


if __name__ == "__main__":
    main()
