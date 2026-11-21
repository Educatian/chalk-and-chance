"""DELETES rows listed by find_test_telemetry.py. Destructive: nothing happens without --confirm.

  python tools/ops/delete_test_telemetry.py --list test_rows.json --wrangler            # shows the plan only
  python tools/ops/delete_test_telemetry.py --list test_rows.json --wrangler --confirm  # deletes on remote D1

Each DELETE names the exact row ids from the reviewed list AND requires the row's anon_id to
match the listed one, so a row the list did not name is never touched. Back up first:
  wrangler d1 export chalk_db --remote --output backup.sql
"""
import argparse
import json
import os
import sqlite3
import subprocess
import sys
import tempfile

BATCH = 200


def statements(rows):
    out = []
    for i in range(0, len(rows), BATCH):
        chunk = rows[i:i + BATCH]
        ids = ",".join(str(int(r["id"])) for r in chunk)
        anons = ",".join("'%s'" % str(r["anon_id"]).replace("'", "''") for r in {r["anon_id"]: r for r in chunk}.values())
        out.append("DELETE FROM telemetry_anon_events WHERE id IN (%s) AND anon_id IN (%s)" % (ids, anons))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--list", required=True, help="JSON written by find_test_telemetry.py --out")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--sqlite")
    src.add_argument("--wrangler", action="store_true")
    ap.add_argument("--db", default="chalk_db")
    ap.add_argument("--local-d1", action="store_true")
    ap.add_argument("--confirm", action="store_true", help="actually delete (otherwise only print the plan)")
    a = ap.parse_args()
    data = json.load(open(a.list, encoding="utf8"))
    if data.get("table") != "telemetry_anon_events" or not isinstance(data.get("rows"), list):
        sys.exit("refusing: %s is not a list written by find_test_telemetry.py" % a.list)
    rows = data["rows"]
    stmts = statements(rows)
    print("plan: delete %d rows from telemetry_anon_events in %d statement(s), %d browser ids"
          % (len(rows), len(stmts), len({r["anon_id"] for r in rows})))
    for s in stmts[:3]:
        print("  " + (s if len(s) < 160 else s[:157] + "..."))
    if not a.confirm:
        print("dry run: nothing deleted. Add --confirm to delete.")
        sys.exit(2)
    if a.sqlite:
        con = sqlite3.connect(a.sqlite)
        with con:
            n = sum(con.execute(s).rowcount for s in stmts)
        con.close()
        print("deleted %d rows" % n)
    else:
        sql = os.path.join(tempfile.mkdtemp(), "delete_test_telemetry.sql")   # file, not --command (cmd.exe quoting)
        open(sql, "w", encoding="utf8").write(";\n".join(stmts) + ";\n")
        cmd = ["wrangler", "d1", "execute", a.db, "--file", sql] + ([] if a.local_d1 else ["--remote"])
        subprocess.run(cmd, check=True, shell=sys.platform == "win32")
        print("done; re-run find_test_telemetry.py to confirm 0 rows remain")


if __name__ == "__main__":
    main()
